# Feature template

Copy this folder only after a mobile capability is approved. Keep role-specific pages, widgets, state, services, and models together.

Before adding a component or model here, check whether another role can use it:

- Framework-level visual primitives and theme-independent helpers belong in `lib/core`.
- Cross-role business models and composed widgets belong in `lib/shared`.
- Widgets and state that encode one role's workflow remain in `lib/features/<feature>`.

Features must not import presentation widgets from another feature. Promote the shared behavior first and expose role-specific actions through callbacks or composition.
