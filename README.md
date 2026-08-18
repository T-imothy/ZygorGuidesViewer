# Zygor Guides Viewer — Classic 1.12 Backport

A compatibility backport of Zygor Guides Viewer for the original World of Warcraft 1.12.1 client. The project adapts the guide engine, navigation, quest tracking, and interface to Vanilla-era Lua and APIs.

> **Development preview:** the backport is actively tested and is not yet considered a finished release. Expect guide-data corrections and compatibility updates as more routes are played through.

## Compatibility

- World of Warcraft client: `1.12.1`
- AddOn interface: `11200`
- Current development build: `TEST343`
- Updates are checked and installed by the external addon launcher. The WoW
  1.12 addon sandbox cannot contact GitHub directly.
- The technical diagnostics workspace is hidden at login and opens only from
  the compact guide window's **Diag** button.
- Installation folder: `ZygorGuidesViewer`

## Features

- Compact, resizable guide window with manual and automatic step modes
- Quest acceptance, completion, turn-in, item, kill, and exploration tracking
- On-screen directional arrow with distance and arrival feedback
- World-map and minimap waypoints, route dots, and quest-objective markers
- Quest-assistance details in unit and object tooltips
- Travel handoffs for hearthstones, flight paths, boats, trams, portals, and zone transitions
- Guide selection for Alliance and Horde leveling routes
- Built-in diagnostics for guide state, quest matching, waypoints, and route troubleshooting
- Single-folder packaging of the legacy libraries required by the backport

## Installation

1. Download or clone this repository.
2. Copy the `ZygorGuidesViewer` folder into your game installation at `Interface/AddOns`.
3. Enable **Zygor Guides Viewer** from the AddOns list at character selection.
4. Restart the client or reload the user interface.

Use `/zygor` in chat to show or hide the guide window. The **Guide**, **Help**, and **Diag** buttons provide guide selection, usage information, and troubleshooting details.

## Reporting a problem

Useful reports include:

- the guide name and step number;
- character race, class, and level;
- what the step expected and what happened instead;
- a screenshot with the diagnostics window visible when possible.

The starter routes and travel transitions receive the most testing, but the complete guide collection still needs broader playthrough coverage.

## Attribution and content notice

This repository is a compatibility and preservation-oriented backport. Zygor, World of Warcraft, and related names and assets belong to their respective owners. Guide text and bundled legacy components may retain their original authorship and licensing terms; review those terms before redistributing or repackaging the project.
