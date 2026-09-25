# Charades

Charm++ Adaptive Discrete Event Simulation: a parallel discrete event
simulation (PDES) engine built on Charm++. Charades is the successor to the
POSE library that shipped inside Charm++ through release v8.0.2.

## Status

Maintained by the Parallel Programming Laboratory (UIUC). This repository
was transferred from the Charmworks organization on 2026-09-25 and is a
snapshot of the 2019 code base, with the PPL and Charmworks development lines
merged. It is being brought up to date against current Charm++ (classic and
reconverse runtimes); see the issues for the current state.

## Layout

- `src/` simulation core, GVT algorithms, scheduler, collections, statistics;
  builds `libcharades.a`
- `models/` example models: PHOLD, PCS, dragonfly, traffic, and a minimal
  `example`
- `tests/` test driver (`test.py`) and configurations
- `doc/` Doxygen documentation, starting with `doc/getting_started.dox` and
  `doc/model-conversion.md`

## Building

1. Copy `src/config.mk.template` to `src/config.mk` and set the paths to your
   Charm++ installation and to this `src/` directory.
2. `make` inside `src/`. The library and object files land in `src/build/`.
3. Build a model from its directory under `models/`; each model's Makefile
   includes the same `config.mk` and links `libcharades.a`.

Charm++ must already be built; see https://charm.readthedocs.io/. The
original documentation notes that only non-SMP Charm++ builds were supported.

## Running

Classic Charm++: `./charmrun +pN ./model <model-args>`.
Charm++ on reconverse: `./model +pe N <model-args>` (no charmrun).

## Authors

Eric Mikida, Elsa Gonsiorowski, Nikhil Jain and collaborators at the
Parallel Programming Laboratory and Charmworks.

## License

Apache License 2.0, the same license as Charm++. See `LICENSE`.
