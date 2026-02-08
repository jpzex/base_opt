<h1 align="center">base_opt — Android Bottleneck Removal</h1>

<div align="center">
  <img src="https://img.shields.io/badge/Script-base-blue.svg?style=flat-square" />
  <img src="https://img.shields.io/badge/Target-Android%2013%2B-purple.svg?style=flat-square" />
  <img src="https://img.shields.io/badge/Kernel-Linux%205.4+-orange.svg?style=flat-square" />
</div>
<div align="center">
  <a href="https://github.com/jpzex/batt_opt">
  <img src="https://img.shields.io/badge/SUGGESTED_COMBO-base+batt-green.svg?style=flat-square" /></a>
  <a href="https://github.com/jpzex/game_opt">
  <img src="https://img.shields.io/badge/SUGGESTED_COMBO-base+game-red.svg?style=flat-square" /></a>
</div>

---

## Overview

**base_opt** is the foundational optimization layer of this project.  
Its sole purpose is to remove unnecessary kernel bottlenecks and conservative defaults that limit responsiveness and throughput on modern Android devices.

It does **not** optimize for battery life nor for maximum performance.  
Instead, it establishes a **clean, neutral baseline** that stops the kernel from working against the device.

---

## Design Intent

- Eliminate artificial latency
- Remove legacy safeguards meant for servers or desktops
- Normalize kernel behavior for mobile SoCs
- Provide a predictable base for higher-level profiles

---

## How It Works

- Disables excessive logging, watchdogs, and panic paths
- Relaxes overly conservative scheduler heuristics
- Normalizes memory reclaim and watermark behavior
- Removes unnecessary background throttling
- Cleans up networking buffers without biasing traffic

All changes are **static and deterministic**, avoiding aggressive boosting or power bias.

---

## Impact

- Lower baseline system latency
- Smoother UI and task scheduling
- More consistent performance across workloads
- Minimal impact on thermals and battery by itself


`base_opt` can be paired with `batt_opt` or `game_opt` depending on your desire, but it can also be used standalone.

Remember to never use `batt_opt` and `game_opt` together because they intentionally and completely conflict with each other.
