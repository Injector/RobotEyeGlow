A plugin that creates robot eyes from MvM and attaches them to robot players.

Player must have robot model which starts with "models/bots/" to apply robot eye glow. Use Be The Robot plugin for that.

## TODO List:
* Custom robot eye color.
* Translations system support.
* Detect robot model change (from regular to giant and giant to regular) to change eye glow position.
* Add support for custom robot models

## Commands:
``sm_robot_eyes`` (Admin Access: none, available to everyone) - Turn on or off the eyes

``sm_yellow_robot_eyes`` (Admin Access: Generic) - Turn on or off the hardcore eyes

## ConVars:
``sm_robot_eyes_alert`` (Default: 1) - Alert robot player that they can turn on eye glow (1 Enabled / 0 Disabled)

``sm_robot_eyes_cant_turn_off`` (Default: 0) - Robot players can't turn off eye glow (Combines with sm_robot_eyes_by_default) (1 Enabled / 0 Disabled)

``sm_robot_eyes_by_default`` (Default: 0) - Enable robot eye glow by default (1 Enabled / 0 Disabled)
