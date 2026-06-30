# Product

## Register

product

## Users

Gleam developers integrating Fluid protocol clients. They are usually working inside the Fluid/Gleam stack, trying to encode, decode, and test canonical Fluid Socket.IO frames without pulling in unrelated Phoenix-specific abstractions or Node-based test clients.

## Product Purpose

dewdrop provides the canonical Fluid Framework protocol codec for Gleam: Socket.IO event frames, Fluid event vocabulary, and integration points for channel clients such as aquamarine. Success means a developer can confidently speak Fluid from Gleam, build levee integration tests, and understand the wire format without reverse-engineering JavaScript client behavior.

## Brand Personality

Precise, lightweight, protocol-literate. The project should feel like a small, sharp protocol tool: confident about wire-level details, economical in presentation, and clear about the boundaries between Fluid, Socket.IO, Phoenix, aquamarine, roost, and levee.

## Anti-references

Avoid generic SaaS marketing polish and visual fluff. Future UI or documentation should not bury protocol facts under decorative cards, vague claims, gradient emphasis, or water-themed ornamentation that distracts from the wire format.

## Design Principles

1. Make the wire shape visible: examples should show the exact frames and arguments developers need to reason about.
2. Prefer sharp boundaries over broad abstraction: distinguish Fluid Socket.IO behavior from Phoenix channel conventions whenever they could be confused.
3. Keep the surface light: every visual or interaction choice should help developers read, compare, test, or copy protocol behavior.
4. Optimize for integration confidence: docs and tools should make compatibility assumptions, reply matching, and downstream stack relationships explicit.

## Accessibility & Inclusion

Use WCAG 2.2 AA as the baseline for any future UI or documentation surface. Preserve keyboard-first navigation for docs and tools, maintain readable contrast for code and prose, and provide reduced-motion alternatives for any non-essential animation.
