# REAPER_TrackRouting2Graph
![](https://i.imgur.com/FMjiOWY.gif)

GUI implementation and other fix for TrackRouting2dot script in REAPER
Initially from [Reaper Community](https://forums.cockos.com/showthread.php?t=239250&page=1), User [Fabian](https://forums.cockos.com/member.php?u=10450)

## Preparation
1. Install [Graphviz](http://graphviz.org/download/) on your computer
2. Check the **Graphviz Path**, it should be like: `/some/thing/here/graphviz/bin/dot/`
```bash
where dot
```
3. Goto the lua script and change the variable `default_dot_path` in line 23 to the result of the previous command.
4. Enjoy


## Optimize RoadMap:
* [DONE!] Simple GUI interface
* [DONE!] Graphviz path check
* [DONE!] IO path & item Check
* [DONE!] user message window
* Windows OS File manager API (I only have Mac so ...)

