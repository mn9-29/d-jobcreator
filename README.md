# d-jobcreator

A job creator script for **FiveM** with in-game admin UI for managing jobs,
job grades, job garages and job stashes.

## Supported frameworks

Works on **ESX**, **QBCore** and **QBX** — the framework is auto-detected at
runtime (or forced via `Config.Framework`).

## Dependencies

- `ox_lib`
- `ox_target`
- `oxmysql`
- `ox_inventory` (for job stashes)
- A supported framework: `es_extended` **or** `qb-core` **or** `qbx_core`

## Installation

1. Place the resource in your `resources` folder.
2. Import `d_garages.sql` into your database (it safely creates the
   `jobs`, `job_grades` and `d_garages` tables and adds the stash columns
   if they don't already exist).
3. Add `ensure d-jobcreator` to your `server.cfg`.
4. Configure allowed admin groups and options in `config.lua`.

> Jobs created through the UI are written to the database **and** registered
> live with the active framework (ESX `RefreshJobs`, QBX/QBCore `CreateJobs`),
> so they work without a restart.

## Usage

- `/jobcreator` — open the creator UI (admin only, validated server-side).
- `reloadgarages` — reload garages from DB (console only).
- `reloadstashes` — reload stashes from DB (console only).

## Security

All privileged actions are validated **server-side** (permission + input
validation + anti-spam cooldown). Client-side checks are for UX only and are
never trusted.

## Support

For suggestions or support, check out our Discord:
https://discord.gg/4QXR8xCamK
