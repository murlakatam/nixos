{...}: {
  # RAM swap file allocation
  zramSwap = {
    enable = true;
    # one of "lzo", "lz4", "zstd"
    algorithm = "zstd";

    priority = 5;

    memoryPercent = 15;
  };
}
