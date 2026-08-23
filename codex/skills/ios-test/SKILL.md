---
name: ios-test
description: "Build an iOS app, launch it in the simulator, take a screenshot, and optionally run UI tests when asked to verify iOS behavior visually."
---

# iOS Test

Build before testing if code changed. Launch the requested simulator/app, wait for the target screen, capture a screenshot, display it when possible, run available UI tests when appropriate, and report visible behavior against the user's screen hint.

If build or launch fails, report the concrete error and stop or fix only if the user requested implementation.
