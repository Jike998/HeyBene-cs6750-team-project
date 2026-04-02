# OpenBene APK Migration Plan

This document covers the second phase of the repository plan: migrating selected APK/Android-related functionality from OpenBene into this workspace.

## Goal

Reuse the parts we need from OpenBene without copying an entire old project into the team workspace.

## Migration Principle

Do not migrate everything at once.

Instead:

1. inventory what is needed
2. isolate reusable Android logic
3. bridge it behind adapters
4. connect it to the new apps

## Target Landing Zones

### `packages/openbene_bridge`

Use this for reusable Android or protocol bridge code that should not live directly inside one app UI.

### `packages/shared_models`

Use this for shared messages, enums, payloads, and protocol constants.

### `apps/control_app/android` or `apps/robot_app/android`

Use these only for app-specific Android wiring such as manifests, permissions, and integration glue.

## Suggested Migration Steps

### Step 1. Inventory

List:

- source files to migrate
- what each file does
- whether it is UI, service, protocol, or platform glue
- whether it is needed by `control_app`, `robot_app`, or both

### Step 2. Separate Concerns

Split the candidate files into:

- reusable bridge logic
- app-specific UI code
- Android manifest / permission setup
- device-only dependencies

### Step 3. Migrate Minimal Bridges First

Move only the smallest useful subset first, such as:

- connection adapters
- camera/network bridges
- protocol translation

### Step 4. Add Shared Models

Move protocol payloads and common data structures into `packages/shared_models`.

### Step 5. Test In Layers

Test in this order:

1. compile-time wiring
2. app startup
3. local integration
4. real device / hardware validation

## What To Avoid

- copying the entire old APK project into `apps/`
- mixing old OpenBene UI code directly into the new Flutter UI
- putting hardware-specific logic into `presentation`

