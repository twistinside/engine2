# Engine2 Writing Style Guide

## Purpose

Write clear technical prose for experienced software engineers. Help the reader understand the result, behavior, decision, or required action without making them extract it from background material.

Prefer clarity over cleverness, precision over flourish, and brevity without loss of necessary technical detail.

This guide applies to prose added to or substantially revised in the repository, including:

- DocC articles and API documentation
- README and contributor guidance
- Quick Help documentation comments
- inline code comments
- diagnostics and user-facing text

It does not require unrelated editorial cleanup during a focused code change.

Code comments are technical prose and must follow every applicable rule in this guide. This requirement includes documentation comments, inline comments, block comments, and comments in tests.

## Order Information for the Reader

- Lead with the purpose, conclusion, observable behavior, or required action.
- Put the information that affects the most readers first.
- Introduce the common case before exceptions.
- Describe behavior and contracts before implementation details.
- Present process instructions in execution order.
- Move background material later unless the reader needs it to understand the result.
- Use headings, lists, tables, and examples only when they make the information easier to find or understand.

A long document should give the reader a reliable map through descriptive headings and, when useful, a table of contents.

## Write for the Intended Audience

Assume an experienced software-engineering audience unless the document identifies another reader.

- Do not explain familiar programming concepts without a reason.
- Explain repository-specific concepts, contracts, and vocabulary where the reader first needs them.
- Use established Engine2 terms consistently. Do not vary terminology for style.
- Use a concrete example when it clarifies an abstraction, boundary, or failure case.
- Include the detail a reader needs to act correctly, even when that detail makes the text longer.

## Prefer Concrete Language

- Name the type, runtime, system, or caller responsible for an action.
- Prefer concrete verbs over abstract noun phrases.
- Prefer active voice when the actor matters.
- Use passive voice when the result matters and naming the actor would add noise or misstate ownership.
- Prefer everyday English unless a technical term is more precise.
- Define an unfamiliar technical term at first use rather than collecting unnecessary definitions elsewhere.
- Replace adjectives with facts, behavior, or measured properties.

Write:

> `SimulationRuntime` publishes the snapshot after the complete tick.

Avoid:

> The snapshot is seamlessly made available after processing.

Write:

> The cache retains the five most recent results.

Avoid:

> The robust cache provides efficient result access.

## Keep Sentences Direct

- Keep sentences as short as clarity permits.
- Give each sentence one main job.
- Remove redundant words, repeated conclusions, and unnecessary qualifiers.
- Prefer positive statements when they express the rule more directly.
- Express uncertainty only when the evidence is uncertain.
- Keep a qualifier when removing it would overstate a guarantee or broaden a contract.

Words such as *simply*, *obviously*, *clearly*, *robust*, *powerful*, *comprehensive*, and *seamless* often hide missing information. Delete them or replace them with the fact they were meant to convey. Keep one only when it carries a precise, supportable meaning.

Avoid empty framing such as:

- “It is important to note...”
- “It should be noted...”
- “As you can see...”
- “This section will discuss...”
- “In today’s world...”

State the information directly.

## Preserve Technical Precision

Concise writing must remain complete enough to protect the design.

Do not omit:

- ownership and authority
- lifecycle and cadence
- ordering requirements
- invariants and preconditions
- failure and cancellation behavior
- identity, cursor, and provenance relationships
- limitations and unsupported cases
- distinctions between implemented behavior and proposed direction

Use exact scope. Distinguish *all*, *only*, *may*, *must*, and *currently* when those words change the contract.

Do not replace a precise Engine2 term with a looser synonym. In particular, preserve the meanings of Runtime, System, Snapshot, Event, Resource, Asset, Game Content, and App defined by `AGENTS.md` and the architecture documentation.

## Documentation Comments

Give production types meaningful `///` documentation that helps a caller use the API correctly.

- Explain the type’s role, owner, boundary, and important invariants.
- Describe method contracts, accepted inputs, results, side effects, and meaningful failure behavior.
- Document why a restriction exists when that reason prevents misuse.
- Do not restate a declaration in prose.
- Do not promise behavior that the type or its tests do not enforce.

Write:

> `/// Rejects a request whose expected cursor does not match the retained presentation.`

Avoid:

> `/// Captures an offline current capture request.`

## Inline Comments

Use inline comments to explain information the code cannot express clearly:

- why an operation occurs
- why ordering matters
- which invariant is being protected
- why an apparent simplification is unsafe
- what committed state remains after failure or cancellation

Do not narrate syntax, assignments, or straightforward control flow. Prefer clearer names and structure when they can remove the need for a comment.

Keep a comment beside the code it explains. Update or remove it when the behavior changes.

## Revision Checklist

Before finishing prose, ask:

- Does the opening state the result, purpose, behavior, or required action?
- Does each sentence add information the reader needs?
- Can I replace a vague claim with a fact?
- Did I use one term consistently for each concept?
- Did I put the common case before exceptions?
- Did I preserve every relevant invariant, limitation, and ownership boundary?
- Did I distinguish implemented behavior from proposed work?
- Can I remove any word or sentence without losing meaning?
- Do comments explain intent rather than narrate code?
