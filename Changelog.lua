-- Auto-generated during release. Do not edit.
PeaversChangelogs = PeaversChangelogs or {}
PeaversChangelogs["PeaversSplitsData"] = {
    version = "0.1.0",
    entries = {
        { type = "feature", text = "Benchmark Mythic+ boss splits for every dungeon in the current season" },
        { type = "feature", text = "Pooled by exact keystone level, so a +19 is never judged against +10s" },
        { type = "feature", text = "Median plus the interquartile range, so a delta can be told from noise" },
        { type = "feature", text = "Clean public API: GetSplit, GetBosses, GetLevels, GetDungeonName, GetPartition, GetLastUpdate" },
    }
}
