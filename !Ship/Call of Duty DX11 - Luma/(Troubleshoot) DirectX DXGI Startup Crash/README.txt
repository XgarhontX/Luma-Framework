These games are strict with its window/swapchain creation, 
crashing if they don't have it their way.


Steps:
- Uninstall Luma (rename ".addon" file to ".addon 1" or whatever).
- [Do one of the options below.]
- Reinstall Luma (rename).


[Option 1] Borderless Fullscreen (MW1R, AW, IW)
  - In-game settings: "WINDOWED (FULLSCREEN)".
  - (HDR window output upgrade comes with good frame pacing / flip model.)

[Option 2] Exclusive Fullscreen (MW2R)
  - Copy in "Luma_PreventFullscreenState" flag file next to exe.
  - In-game settings: "FULLSCREEN".
  - In-game settings: 60 Hz Refresh Rate. (Luma will override to highest.)
  - (This will unfortunately crash game when Alt-Tabbing out.)

[Option 3] Ask for help...
  - HDRDen Discord