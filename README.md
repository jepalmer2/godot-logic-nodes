# Godot Logic Nodes

Godot Logic Nodes is a free visual scripting addon for Godot 4 that lets developers build gameplay without writing code. You place logic nodes directly in your level and wire them together to create gameplay. 

> **Status:** Alpha (v0.1).

---

## Alpha Content
- [AlphaIntegrationDemo Scene Walkthrough](https://youtu.be/gHKExGlYwMk)
- [Example Workflow](https://youtu.be/_Vp-n8A4pNA)

## Requirements

- Godot **4.7** or newer (built and tested on 4.7.2)
- The standard (GDScript) build of Godot. The addon is written in GDScript. The .NET/C# build hasn't been tested, and there is no C# API for extending the nodes.
- A 3D scene. Logic Nodes are `Node3D`s, so they live in the level next to what they control.

## Installation

1. Copy `godot_logic_nodes/` into your project's `addons/` folder.
2. Open **Project > Project Settings > Plugins** and enable **Godot Logic Nodes**.
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
| **Only Group** | Only react to bodies in this group (default: `player`). Leave empty to react to any body |
| **Collision Mask** | Which physics layers it can detect (default: layer 1) |

For the player to set it off, the player must be a physics body (for example a `CharacterBody3D`) on a layer in the Collision Mask, and in the **Only Group** group. To add the player to a group, select the player, open **Node > Groups** and add `player`.

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
| **Action** | The Input Map action that counts as interacting (default: `interact`) |
| Size, Only Group, Collision Mask | Same as Trigger Volume |

**Setup:** add an action named `interact` in **Project > Project Settings > Input Map** and bind a key to it (for example E). The node shows a warning until the action exists.

**Example:** Interact Zone *On Interact* → Rotate (door) *Start*. The player walks up to the door, presses E, and it opens.

---

## Connecting to built-in Godot nodes

Rows can also target regular Godot nodes, for example calling **Play** on an `AnimationPlayer` or `AudioStreamPlayer3D`. Tick **Show All** at the top of the Logic I/O panel to list every node in the Target dropdown, not just Logic Nodes. The Target Input list then shows that node's actions, such as Play, Stop and Pause.

## Credits

Created by Justin Palmer for ITGM-748 at the Savannah College of Art and Design. 

## License

MIT. See [LICENSE](LICENSE).
