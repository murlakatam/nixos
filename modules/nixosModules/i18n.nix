{...}: {
  # Select internationalisation properties.

  # Set your time zone and NTP server.
  i18n = {
    defaultLocale = "be_BY.UTF-8";
    supportedLocales = [
      "be_BY.UTF-8/UTF-8"
      "en_AU.UTF-8/UTF-8"
      "en_NZ.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_ADDRESS = "en_AU.UTF-8";
      LC_IDENTIFICATION = "en_AU.UTF-8";
      LC_MEASUREMENT = "en_AU.UTF-8";
      LC_MONETARY = "en_AU.UTF-8";
      LC_NAME = "en_AU.UTF-8";
      LC_NUMERIC = "en_AU.UTF-8";
      LC_PAPER = "en_AU.UTF-8";
      LC_TELEPHONE = "en_AU.UTF-8";
      LC_TIME = "en_AU.UTF-8";
    };
  };
}
