# Meeting recorder: local Whisper transcription (whisper.cpp) and `granola`, which records a
# meeting through OBS (obs-websocket), transcribes it and prints the transcript's path.
#   transcribe <file> [model] [whisper-cli args...]   (transcribe help)
#   granola [--no-notify] [--no-mic-check] [model]    (granola help)
#
# Models download on first use into whisper.modelDir (not the nix store). The obs-websocket
# password is never in Nix: granola reads the one OBS generated into its own config at runtime
# (and flips server_enabled on if it is off). Needs PipeWire (pw-record/wpctl) and a
# notification daemon (notify-send).
#
# Per host, NOT here: a GPU-specific OBS wrapper (e.g. nixGL on non-NixOS: set obs.package),
# the GPU backend choice (whisper.acceleration), system-level bits (v4l2loopback, portals).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.meeting-recorder;
  wcfg = cfg.whisper;
  gcfg = cfg.granola;

  whisperCpp =
    {
      cpu = pkgs.whisper-cpp;
      vulkan = pkgs.whisper-cpp.override {vulkanSupport = true;};
      cuda = pkgs.whisper-cpp.override {cudaSupport = true;};
    }
    .${
      wcfg.acceleration
    };
  modelDir = wcfg.modelDir;
  defaultModel = wcfg.defaultModel;
  threads = toString wcfg.threads;
  obsBin = "${cfg.obs.package}/bin/obs";

  # Help text lives in its own Nix string (rendered to a store file) so the
  # shell script stays free of indentation-fragile heredocs.
  helpText = ''
    transcribe — local audio/video → text via Whisper (whisper.cpp)

    usage:
      transcribe <video-or-audio-file> [model] [extra whisper-cli args...]
      transcribe help | -h | --help

    Default model: ${defaultModel}
    Models download on first use into ${modelDir} (cached across runs).
    Always passes -mc 0 -nth 0.6 (against repeat loops) and -t ${threads} (CPU
    fallback when no GPU) to whisper-cli; extra
    args override them.

    Models — pass an alias OR a raw model name as the 2nd argument:

      alias      resolves to     ~size    notes
      fastest    tiny.en         ~75 MB   quickest, lowest accuracy
      fast       base.en         ~142 MB  fine for clear speech
      balanced   small.en        ~466 MB  noticeably better
      accurate   medium.en       ~1.5 GB  strong accuracy, slower
      best       large-v3        ~3.1 GB  highest accuracy, slowest
      turbo      large-v3-turbo  ~1.6 GB  near-large accuracy, much faster

      Aliases pick the English-only (.en) model where one exists. For non-English
      audio, pass a raw multilingual model name instead: tiny, base, small,
      medium, large-v3, large-v3-turbo.

    examples:
      transcribe meeting.mp4                 # default (${defaultModel})
      transcribe meeting.mp4 best            # large-v3, highest accuracy
      transcribe meeting.mp4 turbo           # large-v3-turbo, fast + accurate
      transcribe interview.m4a medium        # multilingual, accurate
      transcribe call.wav small.en -l en -tr # forward extra flags to whisper-cli
  '';
  helpFile = pkgs.writeText "transcribe-help.txt" helpText;

  transcribe = pkgs.writeShellScriptBin "transcribe" ''
    set -euo pipefail

    case "''${1:-}" in
      help|-h|--help) cat ${helpFile}; exit 0 ;;
      "") cat ${helpFile} >&2; exit 1 ;;
    esac

    input="$1"
    model="''${2:-${defaultModel}}"

    # Resolve friendly tier aliases to concrete ggml model names. Raw model
    # names (base.en, large-v3, …) fall through unchanged.
    case "$model" in
      fastest)  model="tiny.en" ;;
      fast)     model="base.en" ;;
      balanced) model="small.en" ;;
      accurate) model="medium.en" ;;
      best)     model="large-v3" ;;
      turbo)    model="large-v3-turbo" ;;
    esac

    if [ ! -f "$input" ]; then
      echo "transcribe: file not found: $input" >&2
      exit 1
    fi

    mkdir -p "${modelDir}"
    model_file="${modelDir}/ggml-$model.bin"
    if [ ! -f "$model_file" ]; then
      echo "transcribe: downloading ggml-$model.bin to ${modelDir}" >&2
      # stdout carries the transcript, so the helper's chatter goes to stderr.
      ${whisperCpp}/bin/whisper-cpp-download-ggml-model "$model" "${modelDir}" >&2
    fi

    # loudnorm: granola recordings come in around -43 dB mean, and Whisper
    # skipped half the speech in one until the audio was normalised.
    tmpwav="$(${pkgs.coreutils}/bin/mktemp --suffix=.wav)"
    trap '${pkgs.coreutils}/bin/rm -f "$tmpwav"' EXIT

    ${pkgs.ffmpeg-headless}/bin/ffmpeg -hide_banner -loglevel error -y \
      -i "$input" -vn -af loudnorm -ar 16000 -ac 1 -c:a pcm_s16le "$tmpwav"

    # -mc 0 drops the previous-text prompt and -nth 0.6 skips likely-silent
    # windows; both stop one hallucinated phrase repeating to the end of the
    # file. Extra args come last, so they override these.
    exec ${whisperCpp}/bin/whisper-cli -pp -mc 0 -nth 0.6 -t ${threads} -m "$model_file" -f "$tmpwav" "''${@:3}"
  '';

  granolaDefaultModel = gcfg.defaultModel; # small.en looped one phrase over a whole 29-min meeting
  micQuietDb = gcfg.micQuietDb;

  # Audio-only OBS scene collection for granola. The default collection holds
  # a PipeWire screen-capture source, and launching OBS with it opens the
  # screencast portal's "share your screen" dialog whenever the saved token
  # goes stale. Copied (not linked) into place because OBS rewrites it.
  # Level chain on both sources: quiet meetings recorded around -41 LUFS.
  # Speech under -30 dB gets +20 dB; louder audio gets compressed 6:1
  # first, and the limiter caps peaks at -1 dB.
  # ponytail: fixed makeup gain; tune output_gain if recordings land far
  # from about -20 LUFS.
  levelFilters = [
    {
      id = "compressor_filter";
      versioned_id = "compressor_filter";
      name = "Compressor";
      settings = {
        ratio = 6.0;
        threshold = -30.0;
        attack_time = 6;
        release_time = 60;
        output_gain = 20.0;
      };
    }
    {
      id = "limiter_filter";
      versioned_id = "limiter_filter";
      name = "Limiter";
      settings = {
        threshold = -1.0;
        release_time = 60;
      };
    }
  ];

  granolaCollection = pkgs.writeText "granola-collection.json" (builtins.toJSON {
    name = "granola";
    current_scene = "Scene";
    current_program_scene = "Scene";
    scene_order = [{name = "Scene";}];
    sources = [
      {
        id = "scene";
        versioned_id = "scene";
        name = "Scene";
        settings = {
          items = [];
          id_counter = 0;
        };
      }
    ];
    DesktopAudioDevice1 = {
      id = "pulse_output_capture";
      versioned_id = "pulse_output_capture";
      name = "Desktop Audio";
      settings.device_id = "default";
      filters = levelFilters;
    };
    AuxAudioDevice1 = {
      id = "pulse_input_capture";
      versioned_id = "pulse_input_capture";
      name = "Mic/Aux";
      settings.device_id = "default";
      filters = levelFilters;
    };
  });

  granolaHelpText = ''
    granola — record a meeting via OBS, transcribe it, print the transcript path

    usage:
      granola [--no-notify] [--no-mic-check] [model] [extra whisper-cli args...]
      granola help | -h | --help

    Starts OBS recording (launching it minimised if it isn't already running),
    waits for you to press Enter, stops the recording, asks what to call it,
    then transcribes the result with `transcribe` and prints the transcript's
    full path. The video recording is kept.

    Transcripts go to ${gcfg.transcriptDir}/<name> <YYYY-MM-DD HH-MM-SS>.txt

    While recording, a critical desktop notification repeats every hour as a
    reminder. Every 5 minutes granola also listens for 10 seconds; if neither
    the desktop audio nor the microphone carries any sound, a notification
    asks whether to stop the recording. Pass --no-notify (first argument) to
    skip both.

    When granola launches OBS itself, it uses an audio-only scene collection
    ("granola": Desktop Audio + Mic/Aux, no screen capture), then restores
    your previous collection when it quits OBS. If OBS is already running,
    granola records with whatever collection is open.

    Before recording, granola checks the default microphone (missing, muted,
    volume 0, or silent signal) and exits with an error if it is broken. Every
    5 minutes during recording it re-checks and raises a critical notification
    while the problem lasts. Pass --no-mic-check (before the model) to skip both,
    e.g. when you only want desktop audio.

    Default model: ${granolaDefaultModel} (see `transcribe --help` for the
    full model/alias list). whisper.cpp does not separate speakers — the
    transcript is one continuous stream of text with timestamps.

    Non-English meetings: the .en-suffixed aliases (fast, balanced, ...) are
    English-only models. Pass a raw multilingual model name instead (tiny,
    base, small, medium, large-v3) AND an explicit -l, since whisper-cli
    defaults to English rather than auto-detecting:

      granola small -l ru    # Russian
      granola small -l auto  # let whisper detect the language

    First run enables obs-websocket (localhost:4455) if it's off. This opens
    that port on ALL network interfaces, permanently, protected only by the
    password OBS already generated in its config — worth knowing if you're on
    untrusted wifi.

    examples:
      granola                # ${granolaDefaultModel}
      granola --no-notify    # no hourly reminder
      granola best           # large-v3, highest accuracy
  '';
  granolaHelpFile = pkgs.writeText "granola-help.txt" granolaHelpText;

  granola = pkgs.writeShellScriptBin "granola" ''
    set -euo pipefail

    case "''${1:-}" in
      help|-h|--help) cat ${granolaHelpFile}; exit 0 ;;
    esac
    notify=1
    micCheck=1
    while true; do
      case "''${1:-}" in
        --no-notify) notify=0; shift ;;
        --no-mic-check) micCheck=0; shift ;;
        *) break ;;
      esac
    done
    model="''${1:-${granolaDefaultModel}}"

    [ -t 0 ] || { echo "granola: needs an interactive terminal" >&2; exit 1; }

    # Prints the peak level (dB) of $1 seconds of the default microphone;
    # extra args go to pw-record. Prints nothing if the probe failed.
    peak_db() {
      local secs="$1" probe
      shift
      probe="$(${pkgs.coreutils}/bin/mktemp --suffix=.wav)"
      ${pkgs.coreutils}/bin/timeout "$secs" ${pkgs.pipewire}/bin/pw-record --rate 16000 --channels 1 "$@" "$probe" >/dev/null 2>&1 || true
      ${pkgs.ffmpeg-headless}/bin/ffmpeg -hide_banner -i "$probe" -af volumedetect -f null - 2>&1 \
        | ${pkgs.gnused}/bin/sed -n 's/.*max_volume: \(-\?[0-9.]*\) dB.*/\1/p'
      rm -f "$probe"
    }
    below() {
      [ -n "$1" ] && [ "$(${pkgs.gawk}/bin/awk -v p="$1" -v t="$2" 'BEGIN { print (p < t) }')" = "1" ]
    }

    # Prints why the default microphone would record silence; prints nothing
    # if it looks fine. OBS's Mic/Aux input follows the system default source,
    # so we check that source: missing, muted, volume 0, or a probe of its
    # signal. The probe catches a headset's hardware mute button, which
    # wpctl cannot see (digital silence reads about -91 dB, a quiet room
    # about -55 dB).
    mic_problem() {
      local vol peak
      if ! vol="$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)"; then
        echo "no default microphone"
        return
      fi
      case "$vol" in
        *MUTED*) echo "default microphone is muted"; return ;;
        "Volume: 0.00"*) echo "default microphone volume is 0"; return ;;
      esac
      peak="$(peak_db 2)"
      if [ -z "$peak" ]; then
        echo "could not read the default microphone"
      elif below "$peak" -75; then
        echo "default microphone is silent (peak $peak dB) — hardware mute or dead device?"
      fi
    }

    # True when the meeting has probably ended: 10 s of digital silence on
    # the default output's monitor (what OBS's Desktop Audio records), then
    # 10 s of no more than room noise on the microphone.
    nobody_talking() {
      below "$(peak_db 10 -P '{ stream.capture.sink = true }')" -75 \
        && below "$(peak_db 10)" ${micQuietDb}
    }

    # Prints property $1 (node.name, node.description) of the default
    # microphone; prints nothing if there is none.
    source_prop() {
      { ${pkgs.wireplumber}/bin/wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || true; } \
        | ${pkgs.gnused}/bin/sed -n "s/.*$1 = \"\(.*\)\"/\1/p" | ${pkgs.coreutils}/bin/head -n1
    }

    if [ "$micCheck" = "1" ]; then
      problem="$(mic_problem)"
      if [ -n "$problem" ]; then
        echo "granola: $problem — fix it, or pass --no-mic-check to record anyway." >&2
        exit 1
      fi
    fi

    wsConfig="$HOME/.config/obs-studio/plugin_config/obs-websocket/config.json"
    if [ ! -f "$wsConfig" ]; then
      echo "granola: $wsConfig not found — launch OBS by hand once first, then re-run." >&2
      exit 1
    fi

    sentinelDir="$HOME/.config/obs-studio/.sentinel"
    shopt -s nullglob
    sentinelFiles=("$sentinelDir"/*)
    shopt -u nullglob
    if [ "''${#sentinelFiles[@]}" -gt 0 ]; then
      echo "granola: OBS may ask about an unclean shutdown on launch — click \"Launch Normally\" (Safe Mode disables WebSockets and granola will fail with no useful error)." >&2
    fi

    wasRunning=0
    if ${pkgs.gnugrep}/bin/grep -q '@/com/obsproject' /proc/net/unix 2>/dev/null; then
      wasRunning=1
    fi

    serverEnabled="$(${pkgs.jq}/bin/jq -r '.server_enabled' "$wsConfig")"
    serverPort="$(${pkgs.jq}/bin/jq -r '.server_port' "$wsConfig")"
    serverPassword="$(${pkgs.jq}/bin/jq -r '.server_password' "$wsConfig")"

    if [ "$serverEnabled" != "true" ]; then
      # Patch atomically (temp file + mv), never via xdg.configFile — OBS
      # rewrites this file at every startup, which would clobber a store
      # symlink and would put the password in the nix store.
      tmpCfg="$(${pkgs.coreutils}/bin/mktemp -p "$(${pkgs.coreutils}/bin/dirname "$wsConfig")" config.json.XXXXXX)"
      ${pkgs.jq}/bin/jq '.server_enabled = true' "$wsConfig" > "$tmpCfg"
      mv "$tmpCfg" "$wsConfig"
      if [ "$wasRunning" = "1" ]; then
        echo "granola: obs-websocket was off and OBS is already running — enabling only takes effect on the next launch. Quit OBS and re-run granola." >&2
        exit 1
      fi
    fi

    export OBS_WEBSOCKET_URL="obsws://localhost:$serverPort/$serverPassword"
    obsCmd="${pkgs.obs-cmd}/bin/obs-cmd"

    # obs-cmd 1.0.1 sometimes aborts mid-meeting (core dump, no output), and
    # one abort once read as "not recording", so granola stopped a live
    # recording. Only a status OBS actually returned counts; a failed call
    # retries, and 5 failures in a row mean OBS is gone.
    is_recording() {
      local out
      for _ in 1 2 3 4 5; do
        if out="$("$obsCmd" recording status 2>/dev/null)"; then
          case "$out" in
            *"Active: true"*) return 0 ;;
            *"Active: false"*) return 1 ;;
          esac
        fi
        sleep 1
      done
      return 1
    }

    if [ "$wasRunning" = "1" ] && is_recording; then
      echo "granola: OBS is already recording — stop it first." >&2
      exit 1
    fi

    mark="$(${pkgs.coreutils}/bin/date +%s)"
    launchedPid=""
    userIni="$HOME/.config/obs-studio/user.ini"
    prevCollection=""
    prevCollectionFile=""
    if [ "$wasRunning" = "1" ]; then
      "$obsCmd" recording start >/dev/null
    else
      collectionFile="$HOME/.config/obs-studio/basic/scenes/granola.json"
      [ -f "$collectionFile" ] || ${pkgs.coreutils}/bin/install -Dm644 ${granolaCollection} "$collectionFile"
      # OBS saves the collection it ran with into user.ini on exit; quit_obs
      # puts these back so a manual OBS launch keeps your usual scenes.
      if [ -f "$userIni" ]; then
        prevCollection="$(${pkgs.gnused}/bin/sed -n 's/^SceneCollection=//p' "$userIni")"
        prevCollectionFile="$(${pkgs.gnused}/bin/sed -n 's/^SceneCollectionFile=//p' "$userIni")"
      fi
      # setsid: insulates OBS from this terminal's Ctrl-C (SIGINT hits
      # OBS's ConfirmOnExit modal; only SIGTERM after a confirmed stop is safe).
      setsid ${obsBin} --collection granola --startrecording --minimize-to-tray >/dev/null 2>&1 &
      launchedPid="$!"
    fi

    echo "▶ waiting for OBS to confirm recording…" >&2
    started=0
    for _ in $(seq 1 60); do
      if is_recording; then
        started=1
        break
      fi
      sleep 1
    done
    if [ "$started" != "1" ]; then
      echo "granola: OBS never confirmed it started recording (60s timeout)." >&2
      if [ -n "$launchedPid" ]; then
        kill -TERM "$launchedPid" 2>/dev/null || true
      fi
      exit 1
    fi

    recordDir="$("$obsCmd" record-directory get 2>/dev/null | ${pkgs.gnused}/bin/sed -n 's/^Current record directory: //p')"
    recordDir="''${recordDir:-$HOME/Videos}"

    # Hourly reminder that the recording is still going, since it's easy to
    # forget after the meeting ends. A critical notification stays on screen
    # until dismissed, wherever focus is. Exits on its own if the recording
    # was stopped from OBS instead.
    reminderPid=""
    if [ "$notify" = "1" ]; then
      (
        elapsed=0
        while sleep 3600 && is_recording; do
          elapsed=$((elapsed + 1))
          ${pkgs.libnotify}/bin/notify-send -u critical -i media-record \
            "granola is still recording" \
            "''${elapsed}h so far. Press Enter in its terminal to stop."
        done
      ) &
      reminderPid="$!"
    fi

    # Every 5 minutes: if nobody is talking, ask whether to stop (the
    # meeting has probably ended). Otherwise re-check the microphone and
    # raise a critical notification (plus a terminal line) while it stays
    # broken.
    watchPid=""
    # Exists once the "nobody is talking" prompt stopped the recording.
    askedStopFile="$(${pkgs.coreutils}/bin/mktemp -u)"
    if [ "$notify" = "1" ] || [ "$micCheck" = "1" ]; then
      (
        while sleep 300 && is_recording; do
          if [ "$notify" = "1" ] && nobody_talking; then
            choice="$(${pkgs.libnotify}/bin/notify-send -u critical -i media-record \
              -A stop="Stop recording" -A keep="Keep recording" \
              "granola: nobody is talking" "The meeting may be over. Stop the recording?" || true)"
            if [ "$choice" = "stop" ]; then
              : > "$askedStopFile"
              "$obsCmd" recording stop >/dev/null 2>&1 || true
              break
            fi
          elif [ "$micCheck" = "1" ]; then
            problem="$(mic_problem)"
            if [ -n "$problem" ]; then
              echo "granola: $problem" >&2
              ${pkgs.libnotify}/bin/notify-send -u critical -i microphone-sensitivity-muted \
                "granola: microphone problem" "$problem. The recording has no audio from you."
            fi
          fi
        done
      ) &
      watchPid="$!"
    fi

    # OBS opens Mic/Aux on the device "default" meant at start and keeps
    # reading it after it disappears (USB headset unplugged mid-meeting),
    # while the mic check above probes the new default and passes. So follow
    # the system default: when it changes, point Mic/Aux at the new device.
    # do_stop puts "default" back so the saved collection isn't pinned.
    reboundFile="$(${pkgs.coreutils}/bin/mktemp -u)"
    (
      last="$(source_prop node.name)"
      while sleep 5 && is_recording; do
        cur="$(source_prop node.name)"
        if [ -n "$cur" ] && [ "$cur" != "$last" ]; then
          last="$cur"
          if "$obsCmd" input settings "Mic/Aux" --set "{\"device_id\":\"$cur\"}" >/dev/null 2>&1; then
            touch "$reboundFile"
            ${pkgs.libnotify}/bin/notify-send -u critical -i audio-input-microphone \
              "granola: microphone switched" "Now recording from $(source_prop node.description)."
          else
            ${pkgs.libnotify}/bin/notify-send -u critical -i microphone-sensitivity-muted \
              "granola: microphone changed" "OBS did not switch to $(source_prop node.description). Set Mic/Aux in OBS by hand."
          fi
        fi
      done
    ) &
    followPid="$!"

    stopped=0
    do_stop() {
      if [ "$stopped" = "1" ]; then return 0; fi
      stopped=1
      for pid in "$reminderPid" "$watchPid" "$followPid"; do
        if [ -n "$pid" ]; then
          ${pkgs.procps}/bin/pkill -P "$pid" 2>/dev/null || true
          kill "$pid" 2>/dev/null || true
        fi
      done
      if is_recording; then
        "$obsCmd" recording stop >/dev/null 2>&1 || true
        # recording stop only acknowledges the request — it does not block
        # until OBS has actually finalised the output (upstream TODO).
        for _ in $(seq 1 30); do
          if ! is_recording; then break; fi
          sleep 1
        done
      fi
      if [ -e "$reboundFile" ]; then
        "$obsCmd" input settings "Mic/Aux" --set '{"device_id":"default"}' >/dev/null 2>&1 || true
        rm -f "$reboundFile"
      fi
    }
    quit_obs() {
      # A second granola may have started recording in this OBS while we
      # transcribed; leave OBS running for it.
      if [ -n "$launchedPid" ] && ! is_recording; then
        kill -TERM "$launchedPid" 2>/dev/null || true
        wait "$launchedPid" 2>/dev/null || true
        if [ -n "$prevCollection" ] && [ -n "$prevCollectionFile" ]; then
          ${pkgs.gnused}/bin/sed -i \
            -e "s|^SceneCollection=granola$|SceneCollection=$prevCollection|" \
            -e "s|^SceneCollectionFile=granola.json$|SceneCollectionFile=$prevCollectionFile|" \
            "$userIni"
        fi
      fi
    }
    # INT/TERM must exit: a handler that returns lets the script continue
    # (Ctrl-C at the name prompt used to leave it open). Exiting fires EXIT.
    # Record the microphone at 100% (laptop digital mics often sit near 30%
    # and record near -58 LUFS); put its old volume back on exit.
    micId="$(${pkgs.wireplumber}/bin/wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | ${pkgs.gnused}/bin/sed -n '1s/^id \([0-9]*\),.*/\1/p')"
    micVol="$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $2}')"
    [ -n "$micId" ] && ${pkgs.wireplumber}/bin/wpctl set-volume "$micId" 1.0 || true
    restore_mic() {
      [ -n "$micId" ] && [ -n "$micVol" ] && ${pkgs.wireplumber}/bin/wpctl set-volume "$micId" "$micVol" 2>/dev/null || true
    }
    trap 'do_stop; restore_mic; quit_obs' EXIT
    trap 'exit 130' INT TERM

    echo "" >&2
    echo "● recording → $recordDir  [Enter] to stop…" >&2
    # Poll, so a stop from OBS or from the "nobody is talking" notification
    # also ends the wait. read -t returns >128 on timeout.
    enterPressed=0
    while is_recording; do
      rc=0
      read -r -t 5 || rc=$?
      if [ "$rc" -le 128 ]; then
        enterPressed=1
        break
      fi
    done
    # Neither Enter nor the "nobody is talking" prompt stopped it: OBS
    # stopped or crashed, and the rest of the meeting is not being recorded.
    if [ "$enterPressed" = "0" ] && [ ! -e "$askedStopFile" ]; then
      echo "granola: the recording stopped at $(${pkgs.coreutils}/bin/date +%H:%M) without Enter." >&2
      ${pkgs.libnotify}/bin/notify-send -u critical -i dialog-warning \
        "granola: recording stopped" \
        "It stopped at $(${pkgs.coreutils}/bin/date +%H:%M) without you pressing Enter. If the meeting is still going, run granola again." || true
    fi
    rm -f "$askedStopFile"
    do_stop

    # Find the new file rather than trusting `recording stop`'s output (it
    # discards the outputPath obs-websocket returns). Format-agnostic (not a
    # *.mkv glob) so switching OBS's recording format doesn't break this.
    markFile="$(${pkgs.coreutils}/bin/mktemp)"
    ${pkgs.coreutils}/bin/touch -d "@$mark" "$markFile"
    candidates=()
    while IFS= read -r -d "" f; do
      candidates+=("$f")
    done < <(${pkgs.findutils}/bin/find "$recordDir" -maxdepth 1 -type f -newer "$markFile" -print0)
    rm -f "$markFile"

    if [ "''${#candidates[@]}" -eq 0 ]; then
      echo "granola: could not find the new recording in $recordDir" >&2
      exit 1
    fi
    recording=""
    recordingMtime=0
    for f in "''${candidates[@]}"; do
      m="$(${pkgs.coreutils}/bin/stat -c '%Y' "$f")"
      if [ "$m" -gt "$recordingMtime" ]; then
        recordingMtime="$m"
        recording="$f"
      fi
    done

    # mkv reads as valid mid-write, so confirm size stability (two samples,
    # 1s apart) before handing it to transcribe — otherwise the tail of the
    # meeting can be silently dropped.
    prevSize=-1
    for _ in $(seq 1 30); do
      size="$(${pkgs.coreutils}/bin/stat -c '%s' "$recording")"
      if [ "$size" = "$prevSize" ]; then break; fi
      prevSize="$size"
      sleep 1
    done

    echo "" >&2
    read -r -p "Name this recording: " name
    if [ -z "$name" ]; then
      name="$(${pkgs.coreutils}/bin/basename "$recording")"
    fi
    name="''${name//\//_}"

    inboxDir="${gcfg.transcriptDir}"
    mkdir -p "$inboxDir"
    timestamp="$(${pkgs.coreutils}/bin/date +'%Y-%m-%d %H-%M-%S')"
    out="$inboxDir/$name $timestamp.txt"
    if [ -f "$out" ]; then
      echo "granola: $out already exists — refusing to overwrite." >&2
      exit 1
    fi

    echo "⧗ transcribing ($model)…" >&2
    tmpOut="$(${pkgs.coreutils}/bin/mktemp -p "$inboxDir" .granola-transcript.XXXXXX)"
    if ! ${transcribe}/bin/transcribe "$recording" "$model" "''${@:2}" > "$tmpOut"; then
      rm -f "$tmpOut"
      echo "granola: transcription failed" >&2
      exit 1
    fi
    mv "$tmpOut" "$out"
    echo "$out"
  '';

  enabledByDefault = desc:
    lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "${desc} (only when dotfiles.meeting-recorder.enable is set).";
    };
in {
  options.dotfiles.meeting-recorder = {
    enable = lib.mkEnableOption "meeting recorder (whisper.cpp `transcribe`, OBS, `granola`)";
    whisper = {
      acceleration = lib.mkOption {
        type = lib.types.enum ["cpu" "vulkan" "cuda"];
        default = "cpu";
        description = "whisper.cpp backend. vulkan works on most GPUs (AMD/Intel/NVIDIA) and builds quickly; cuda needs NVIDIA and compiles locally unless a CUDA binary cache is configured.";
      };
      defaultModel = lib.mkOption {
        type = lib.types.str;
        default = "large-v3-turbo";
        description = "Default ggml model for `transcribe` (an alias or a raw model name).";
      };
      modelDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.cacheHome}/whisper";
        defaultText = lib.literalExpression ''"''${config.xdg.cacheHome}/whisper"'';
        description = "Where models are downloaded on first use (outside the nix store, so GC keeps them).";
      };
      threads = lib.mkOption {
        type = lib.types.ints.positive;
        default = 12;
        description = "whisper-cli -t (CPU threads; matters for the CPU backend and fallback).";
      };
    };
    obs = {
      enable = enabledByDefault "install OBS Studio (plus a Wayland desktop-entry fix)";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.obs-studio;
        defaultText = lib.literalExpression "pkgs.obs-studio";
        description = "Package providing bin/obs that granola launches and that is installed with high priority. On non-NixOS, set it to a nixGL wrapper around pkgs.obs-studio.";
      };
      extras.enable = enabledByDefault "qpwgraph (per-application audio routing into OBS) and mpv (playback)";
    };
    granola = {
      enable = enabledByDefault "`granola` (record a meeting via OBS, transcribe it)";
      transcriptDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/docs/ai-brain/Inbox";
        defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/docs/ai-brain/Inbox"'';
        description = "Where granola writes `<name> <YYYY-MM-DD HH-MM-SS>.txt` transcripts.";
      };
      defaultModel = lib.mkOption {
        type = lib.types.str;
        default = wcfg.defaultModel;
        defaultText = lib.literalExpression "config.dotfiles.meeting-recorder.whisper.defaultModel";
        description = "Default model for granola transcriptions.";
      };
      micQuietDb = lib.mkOption {
        type = lib.types.str;
        default = "-45";
        description = "Mic peak (dB) under which the room counts as quiet for the 'nobody is talking' prompt; raise it if the prompt fires mid-meeting (room noise reads about -55 dB).";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = [whisperCpp transcribe];
    }
    (lib.mkIf gcfg.enable {
      home.packages = [pkgs.obs-cmd granola];
    })
    (lib.mkIf cfg.obs.enable {
      # Screen + meeting recorder for Wayland: video via the PipeWire screencast portal.
      # A wrapper (obs.package != obs-studio) shadows obs-studio's bin/obs; obs-studio
      # itself stays at normal priority so the desktop entry below overrides its own.
      home.packages =
        [pkgs.obs-studio]
        ++ lib.optional (cfg.obs.package != pkgs.obs-studio) (lib.hiPrio cfg.obs.package);

      # The upstream .desktop sets StartupWMClass=obs, but on Wayland OBS reports
      # app_id=com.obsproject.Studio, so GNOME's dock can't pair the window to the
      # icon and shows the raw app_id as the title.
      xdg.desktopEntries."com.obsproject.Studio" = {
        name = "OBS Studio";
        genericName = "Streaming/Recording Software";
        exec = "obs";
        icon = "${pkgs.obs-studio}/share/icons/hicolor/256x256/apps/com.obsproject.Studio.png";
        terminal = false;
        type = "Application";
        categories = ["AudioVideo" "Recorder"];
        startupNotify = true;
        settings.StartupWMClass = "com.obsproject.Studio";
      };
    })
    (lib.mkIf (cfg.obs.enable && cfg.obs.extras.enable) {
      home.packages = [pkgs.qpwgraph pkgs.mpv];
    })
  ]);
}
