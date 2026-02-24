class MemoryData {
  final bool hasMemory;
  final DateTime? lastConsolidated;
  final bool isStale;

  const MemoryData({
    this.hasMemory = false,
    this.lastConsolidated,
    this.isStale = false,
  });

  static const empty = MemoryData();
}
