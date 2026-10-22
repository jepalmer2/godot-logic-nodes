# Godot Logic Nodes

Godot Logic Nodes is a free visual scripting addon for Godot 4 that lets developers build gameplay without writing code. You place logic nodes directly in your level and wire them together to create gameplay. 

> **Status:** Beta (v0.2).

---

## Supporting Content
- [AlphaIntegrationDemo Scene Walkthrough](https://youtu.be/gHKExGlYwMk)
- [Example Workflow](https://youtu.be/_Vp-n8A4pNA)

## Requirements

- Godot **4.7** or newer (built and tested on 4.7.2)
- The standard (GDScript) build of Godot. The addon is written in GDScript. The .NET/C# build hasn't been tested, and there is no C# API for extending the nodes.
- A 3D scene. Logic Nodes are `Node3D`s, so they live in the level next to what they control.

## Installation

1. Copy `godot_logic_nodes/` into your project's `addons/` folder.
2. Open **Project > Project Settings > Plugins** and enable **Godot Logic Nodes**. This also adds the addon's input actions to **Input Map**: `gln_interact` (E) and `gln_move_forward`, `gln_move_back`, `gln_move_left`, `gln_move_right` (WASD). Actions your project already has are left as they are.
3. A new **Logic I/O** tab appears in the bottom panel, and Logic Nodes appear in the **Add Node** dialog (search for "Logic").

---

## How it works

Every Logic Node has **outputs** (things that happen, like *On Trigger Enter*) and **inputs** (things it can do, like *Start*). You connect one node's output to another node's input, and that drives the basic logic for your gameplay.

### The Logic I/O panel

1. Select a Logic Node in the scene. The **Logic I/O** panel opens at the bottom of the editor.
2. Click **Add Output** to add a row.
3. Fill in the row from left to right:

| Column | What it does |
|---|---|
| **My Output** | The event on this node that starts the connection |
| **Target** | The node to send it to. Pick from the list, or click **…** to pick from the scene tree |
| **Target Input** | What the target should do |
| **Delay** | Seconds to wait before sending (0 = right away) |
| **Once** | Only ever send this connection once |
| **✕** | Delete the row |

The **Inputs** tab lists every connection coming *into* the selected node. Double-click one to jump to the node that sends it.

Connections draw as orange wires in the 3D viewport. Every change can be undone with Ctrl+Z.

### Settings every Logic Node has

| Setting | What it does |
|---|---|
| **Start Enabled** | If off, the node ignores everything until it receives **Enable** |
| **Trace** | Prints every input and output of this node to the Output panel. Useful for debugging a chain |

| Input | What it does |
|---|---|
| **Enable** | Turns the node on |
| **Disable** | Turns the node off. It ignores inputs and fires nothing until enabled again |

If a node is set up wrong (no target, a missing input, an empty offset), Godot shows a ⚠ warning icon next to it in the Scene tree. Hover over it to see why.

---

## Node reference

### Auto
Fires once when the scene starts. Use it to kick off anything that should happen on load: start a fan spinning, lock a gate, play intro music.

| Outputs | |
|---|---|
| **On Scene Start** | The scene has finished loading |

| Settings | |
|---|---|
| **Delay** | Extra seconds to wait after the scene loads before firing |

**Example:** Auto *On Scene Start* → Rotate (fan) *Start*, with the Rotate set to Loop.

---

### Relay
Passes a signal on to everything wired to it, optionally after a delay. Use it to fan one event out to many targets, add a pause in the middle of a chain, or make something happen only the first time.

| Inputs | |
|---|---|
| **Trigger** | Pass the signal on |
| **Cancel Pending** | Drop any triggers still waiting on the delay |

| Outputs | |
|---|---|
| **On Trigger** | Fires after **Delay** seconds |

| Settings | |
|---|---|
| **Delay** | Seconds to wait before firing |
| **Fire Once** | Only ever fire once |

**Example:** Trigger Volume *On Trigger Enter* → Relay (Delay 1 s) *Trigger*, then Relay *On Trigger* → Move (spikes) *Start*. The spikes pop up one second after the player steps in.

---

### Move
Slides a node in a straight line between where you placed it and an offset from there. Use it for sliding doors, elevators, platforms and gates.

Put the object you want to move **under** the Move node in the Scene tree, or pick it in **Target**.

| Inputs | |
|---|---|
| **Start** | Start moving. If it's resting at one end, it heads for the other |
| **Stop** | Stop where it is. The next Start carries on in the same direction |

| Outputs | |
|---|---|
| **On Move Start** | Began moving |
| **On Move End** | Arrived at either end |

| Settings | |
|---|---|
| **Target** | The node to move. Leave empty to move this node and its children |
| **Move Offset** | How far the end is from the start, in meters (default: 2 m up) |
| **Speed** | Meters per second |
| **Mode** | **Once**: each Start goes to the other end and stops. **Ping Pong**: goes back and forth until Stop. **Loop**: goes to the end, jumps back to the start, and repeats until Stop |

**Example:** an elevator. Interact Zone *On Interact* → Move *Start* (Mode: Once). Press once to go up, press again to come down.

---

### Rotate
Turns a node between how you placed it and an offset in degrees. Use it for hinged doors, fans, levers and drawbridges.

Put the object you want to turn **under** the Rotate node, or pick it in **Target**. The Rotate node's position is the pivot, so for a door, place it on the hinge.

| Inputs | |
|---|---|
| **Start** | Start turning. If it's resting at one end, it heads for the other |
| **Stop** | Stop where it is. The next Start carries on in the same direction |

| Outputs | |
|---|---|
| **On Rotate Start** | Began turning |
| **On Rotate End** | Arrived at either end |

| Settings | |
|---|---|
| **Target** | The node to turn. Leave empty to turn this node and its children |
| **Rotate Offset** | How far to turn, in degrees around X, Y and Z. A door swinging open is usually (0, 90, 0) |
| **Speed** | Degrees per second |
| **Mode** | Once, Ping Pong or Loop, as in Move |

**Tip:** turn around one axis at a time. Turning on two axes at once can look odd.

---

### Trigger Volume
A box that fires when something walks into it or out of it. Use it for proximity doors, jump scares, music changes and checkpoints. In the editor it shows as a transparent orange box so you can see the space it covers.

| Outputs | |
|---|---|
| **On Trigger Enter** | Something entered the box |
| **On Trigger Exit** | Something left the box |

| Settings | |
|---|---|
| **Size** | Width, height and depth of the box, in meters |
| **Only Group** | Only react to bodies in this group (default: `gln_player`). Leave empty to react to any body |
| **Collision Mask** | Which physics layers it can detect (default: layer 1) |

For the player to set it off, the player must be a physics body (for example a `CharacterBody3D`) on a layer in the Collision Mask, and in the **Only Group** group. To add the player to a group, select the player, open **Node > Groups** and add `gln_player`.

**Example: a proximity door.**
- Trigger Volume *On Trigger Enter* → Rotate (door) *Start*
- Trigger Volume *On Trigger Exit* → Rotate (door) *Start*

With the Rotate set to Once, the door opens when the player walks up and closes when they walk away.

---

### Interact Zone
A Trigger Volume where the player presses a key to use something: a lever, a button, a door handle. It has everything a Trigger Volume has, plus an **On Interact** output.

| Outputs | |
|---|---|
| **On Interact** | The interact key was pressed while the player was inside |
| **On Trigger Enter** | Something entered the zone. Handy for showing a "Press E" prompt |
| **On Trigger Exit** | Something left the zone. Handy for hiding the prompt |

| Settings | |
|---|---|
| **Action** | The Input Map action that counts as interacting (default: `gln_interact`) |
| Size, Only Group, Collision Mask | Same as Trigger Volume |

**Setup:** enabling the plugin adds a `gln_interact` action bound to E. To use another key, change it in **Project > Project Settings > Input Map**. The node shows a warning if the action is missing.

**Example:** Interact Zone *On Interact* → Rotate (door) *Start*. The player walks up to the door, presses E, and it opens.

---

### Timer
Waits a set time, then fires. It can fire once or keep repeating. Use it for timed doors, countdowns, waves of enemies and anything that should happen every few seconds. It pauses when the game is paused.

| Inputs | |
|---|---|
| **Start** | Start counting. After Stop, it carries on with the time that was left. Ignored if it's already running |
| **Stop** | Pause and keep the time left. The next Start carries on from there |
| **Restart** | Start again from the full Wait Time, whether it's running or not |

| Outputs | |
|---|---|
| **On Timeout** | Wait Time ran out |

| Settings | |
|---|---|
| **Wait Time** | Seconds until On Timeout |
| **Repeat** | Off: fire once and stop. On: fire every Wait Time until Stop |
| **Max Repeats** | Only used when Repeat is on. 0 = forever; 3 = fire 3 times, then stop |

**Example:** a timed door. Interact Zone *On Interact* → Move (door) *Start* and → Timer (Wait Time 5 s) *Restart*, then Timer *On Timeout* → Move (door) *Start*. The door opens, then closes by itself 5 seconds later.

---

### Counter
Counts how many times something happened and fires when it reaches a goal. Use it for "hit 3 switches to open the gate" puzzles, or anything that should only happen on the Nth time.

| Inputs | |
|---|---|
| **Add** | Count up by one |
| **Subtract** | Count down by one. Never goes below 0 |
| **Reset** | Go back to Start Count |

| Outputs | |
|---|---|
| **On Count Change** | The count went up, down or was reset. Handy for a "click" sound on each switch |
| **On Goal Reached** | The count reached Goal |

| Settings | |
|---|---|
| **Goal** | Count needed to fire On Goal Reached |
| **Start Count** | Count when the scene loads, and what Reset goes back to |
| **After Goal** | **Stop**: ignores Add and Subtract until Reset. **Reset**: goes straight back to Start Count, so it fires again every Goal adds. **Keep Counting**: keeps going past Goal and only fires again if the count drops below Goal and comes back up |

**Example:** three Trigger Volumes, each *On Trigger Enter* → Counter (Goal 3) *Add*, then Counter *On Goal Reached* → Move (gate) *Start*. The gate opens once the player has stepped on all three pads.

---

### Branch
Remembers one yes/no fact about the level, like "the power is on", and sends an event one of two ways depending on it. Setting the value and checking it are separate inputs, so one part of the level can flip the switch and another can ask about it later.

| Inputs | |
|---|---|
| **Set True** | The value becomes true |
| **Set False** | The value becomes false |
| **Toggle** | Flip the value |
| **Check** | Fire On True or On False for the current value. Doesn't change the value |

| Outputs | |
|---|---|
| **On True** | Check was sent and the value is true |
| **On False** | Check was sent and the value is false |
| **On Value Change** | The value changed (by Set True, Set False or Toggle). Setting it to the value it already has fires nothing |

| Settings | |
|---|---|
| **Start Value** | The value when the scene loads |
| **Check On Change** | Every change also runs Check, so On True / On False fire right away |

The value resets to Start Value every time the scene loads. It isn't saved between play sessions.

**Example:** a door that needs power. Interact Zone (generator) *On Interact* → Branch *Set True*. Interact Zone (door) *On Interact* → Branch *Check*. Branch *On True* → Move (door) *Start*, and Branch *On False* → Audio Clip (buzzer) *Play*.

---

### Audio Clip
Plays a sound from logic. With Loop off, it plays once each time it gets Play (a door creak, a click). With Loop on, it repeats until Stop (an ambient hum, music).

| Inputs | |
|---|---|
| **Play** | Play from the start. With Loop on, it then repeats until Stop |
| **Stop** | Stop the sound. Doesn't fire On Audio End |

| Outputs | |
|---|---|
| **On Audio Start** | Play started the sound |
| **On Audio End** | A one-shot sound reached its end. Never fires with Loop on |

| Settings | |
|---|---|
| **Stream** | The sound file (.wav, .ogg or .mp3) |
| **Loop** | Off: plays once per Play. On: repeats until Stop. Overrides the file's own Loop import setting |
| **Volume Db** | Loudness in decibels (default: -12). 0 = the file's own level; every -6 is about half as loud |
| **Pitch Variation** | Each Play picks a random pitch within ± this amount, so repeated sounds don't feel robotic. 0 = always the same |
| **Positional** | On: the sound comes from this node's spot in the level and fades with distance. Off: same volume everywhere (music, announcements) |
| **Max Distance** | Positional only. Beyond this distance the sound can't be heard. 0 = no limit |
| **Polyphony** | How many copies can play at once. 1 = Play restarts the sound |
| **Bus** | The audio bus it plays on, for separate SFX and Music volume |

**Tip:** for a different sound on each play (footsteps, impacts), put an `AudioStreamRandomizer` in Stream.

**Example:** Move (door) *On Move Start* → Audio Clip (creak) *Play*. Place the Audio Clip at the door so the sound comes from there.

---

### Debug
Shows a short message on the game screen when something reaches it, then passes the event on. Drop it into the middle of a chain to see what fired while you play. Repeated messages stack into one line with a count (×3). For a full log of every input and output, turn on **Trace** instead.

| Inputs | |
|---|---|
| **Trigger** | Show the message, then fire On Show |

| Outputs | |
|---|---|
| **On Show** | The message was shown. Also fires in a release build, where nothing is shown, so the chain keeps working |

| Settings | |
|---|---|
| **Message** | The text to show. Empty shows the node's name |
| **Color** | Text color, so different checkpoints are easy to tell apart |
| **Duration** | Seconds the line stays on screen before it fades |
| **Show Activator** | Adds who set it off, e.g. "Gate open (Player)" |
| **Print To Console** | Also print the line to the Output panel |
| **Debug Builds Only** | Show and print nothing in an exported release game |

**Example:** Counter *On Goal Reached* → Debug ("Gate open") *Trigger*, then Debug *On Show* → Move (gate) *Start*. You see "Gate open" on screen at the moment the gate starts moving.

---

## Connecting to built-in Godot nodes

Rows can also target regular Godot nodes, for example calling **Play** on an `AnimationPlayer` or `AudioStreamPlayer3D`. Tick **Show All** at the top of the Logic I/O panel to list every node in the Target dropdown, not just Logic Nodes. The Target Input list then shows that node's actions, such as Play, Stop and Pause.

## Credits

Created by Justin Palmer for ITGM-748 at the Savannah College of Art and Design. 

## License

MIT. See [LICENSE](LICENSE).
