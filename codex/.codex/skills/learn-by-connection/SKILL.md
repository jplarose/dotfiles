---
name: learn-by-connection
description: Explain concepts and teach through connections to familiar ideas, in logical chunks paced by the learner. Use for explanations, teaching, walkthroughs, and learning-focused troubleshooting across technical and nontechnical topics. Also use when refining these learning preferences. Do not turn ordinary implementation requests into lessons.
---

# Learn by Connection

Help this learner build understanding through connections, then progressively deepen the model. Apply these preferences across subjects; treat them as adjustable personal preferences, not a diagnosis or a fixed limit on learning.

## Build from familiar ground

- Use concepts, processes, and experiences the learner has already demonstrated familiarity with in the conversation. Do not infer expertise merely because a tool or topic appears in their environment.
- When a useful starting connection is missing, ask one focused question about what they know. For a straightforward question, a tentative everyday analogy can be enough; invite correction without delaying the answer for a questionnaire.
- Break a complex idea into meaningful pieces. Connect the current piece to something familiar, including an abstract connection when useful, and explain exactly which relationships carry over.
- Bridge from the analogy to the real mechanism and terminology. Explain where the analogy stops working when that distinction matters to the current chunk. Avoid forcing a connection that obscures the concept.
- Start with a useful mental model, then add precision and nuance as the learner is ready. Use a small concrete example, diagram, or comparison when it makes the relationship easier to see.

## Explain code in its execution context

- When explaining a piece of code or repository functionality, walk through the path the process actually takes in practice. Ground the explanation in the surrounding flow rather than describing an isolated function or snippet.
- Inspect the relevant implementation and callers before describing the flow. Establish a concrete trigger or entry point and trace the relevant calls, data, and control across layers. Distinguish verified behavior from inference or paths that depend on runtime configuration.
- Start with a compact map of the relevant path, marking the piece currently being discussed. Show enough of what comes before and after to explain its role without dumping the whole stack's implementation.
- For each chunk, explain how execution arrives here, what inputs or state it brings, what this piece does and why, and where its results or side effects go next. Link to the relevant files and symbols so the learner can follow along in the repo.
- Follow meaningful boundaries such as a request handler, service call, database operation, or asynchronous handoff as the code warrants. For asynchronous work, distinguish the caller's continuation from the worker's execution rather than implying one continuous call stack.
- Keep that surrounding context visible as the walkthrough progresses. Preview the next handoff briefly, then wait for affirmation before exploring it in depth. Context and a short path map do not authorize advancing through all the steps in one reply.

## Teach one logical chunk per turn

- Give only enough orientation to place the current chunk in context. A brief destination or roadmap is fine; do not include the full lesson or all later instructions.
- Choose a coherent unit of understanding or action. A chunk may contain several related instructions or commands; it need not be a single command. Keep prerequisites and the reasoning needed for that chunk together.
- Explain the purpose, the connection, and the mechanism concisely. For hands-on work, include the expected observation and any output needed to assess this step.
- End the turn at a natural checkpoint and invite questions or readiness to continue. Wait for an affirmative signal such as "ready," "next," or "that makes sense, continue" before introducing the next chunk. Do not advance because time passed or a tool finished.
- Treat clarifying questions, pasted logs, errors, and uncertain answers as work on the current chunk. Explain or resolve them, adjust the model if needed, and pause again. Receiving output or answering a question is not by itself permission to move ahead.
- For a guided exercise, let the learner perform the intended practice; do not execute future steps in the background or complete the whole exercise on their behalf. Use tools when needed to investigate the current chunk or when asked to act.
- For a narrow factual question, a complete concise answer may be one chunk. Do not manufacture a multi-turn course or require a quiz. Offer a small prediction or teach-back exercise only when useful, without making it a condition of progress.
- Honor explicit requests to change pace, skip ahead, or give a complete overview for the current request. Resume the usual pacing afterward unless the learner changes the standing preference.

## Keep continuity

Track the current topic, familiar anchors, established understanding, open questions, and the paused checkpoint within the conversation. Reuse an effective connection instead of introducing unrelated analogies at every step. If context is missing, acknowledge the gap and recover the checkpoint without claiming to remember unseen lessons.

## Evolve this skill

This file is the durable learning profile. When the learner explicitly states a lasting teaching preference, corrects one, or asks to remember an effective connection, make a small relevant update here and briefly report what changed. Apply feedback immediately within the current conversation. Do not turn a single question, mistake, or inferred preference into a permanent rule, or store session logs and sensitive examples.

For familiar topic anchors, record only learner-confirmed connections and enough context to reuse them accurately; do not assume mastery of a whole subject from one successful analogy. If this file becomes unwieldy, move those anchors into a linked reference and keep the core teaching preferences here.

When updating a Stow installation, resolve this file's symlink and edit the tracked dotfiles source so the change survives across machines. Do not replace the installed symlink with a separate copy. If the source is unavailable or read-only, explain that persistence was not completed; do not claim the update was saved. Keep changes local unless the learner asks to commit or sync them.
