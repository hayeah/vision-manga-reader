# Spread Page-Offset Toggle

## Page Types

- **P (Portrait)**: Portrait-oriented image, displayed as part of a pair or as orphan single
- **S (Spread)**: Landscape-oriented image, always displayed alone; acts as a delimiter

## P-Sequences

Consecutive P pages between S delimiters form a **P-sequence**. Each P-sequence can be independently toggled between two groupings.

## Groupings

For a P-sequence of pages `[p0, p1, p2, p3, p4]`:

- **Default**: Pair from the start of the sequence
  - `[p0,p1], [p2,p3], [p4]` — orphan at end if odd count
- **Shifted**: Orphan the first page, then pair the rest
  - `[p0], [p1,p2], [p3,p4]` — orphan at start

### RTL Reading Order Example

Sequence between two spreads: `S, 13, 12, 11, 10, 9, S`

Default (RTL display):

```
S [13] [12,11] [10,9] S
```

Shifted (RTL display):

```
S [13,12] [11,10] [9] S
```

## Toggle Rules

- **S page**: Toggle is disabled (nothing to shift)
- **P-sequence with 1 page**: Toggle is disabled (no pairing possible)
- **P-sequence with ≥2 pages**: Toggle flips between default and shifted grouping
- Each P-sequence has independent toggle state

## Position Tracking

When toggling, the reader preserves position using the **local spread index** within the P-sequence:

- Compute the current spread's local index within its P-sequence
- After toggling and rebuilding, navigate to the same local index (clamped to valid range)

This guarantees:

- A "familiar" page is always visible after toggling (adjacent spreads overlap by one page)
- For odd-length sequences: perfect round-trip (same spread count in both groupings)
- For even-length sequences: round-trip with clamping (shifted has one more spread)

### Round-Trip Example (5 pages, odd)

```
Default:  [p0,p1]₀  [p2,p3]₁  [p4]₂
Shifted:  [p0]₀     [p1,p2]₁  [p3,p4]₂
```

Position 1: `[p2,p3]` ↔ `[p1,p2]` — page p2 is familiar, round-trips perfectly.

### Even-Length Example (4 pages)

```
Default:  [p0,p1]₀  [p2,p3]₁
Shifted:  [p0]₀     [p1,p2]₁  [p3]₂
```

Position 0: `[p0,p1]` ↔ `[p0]` — page p0 is familiar.
Position 1: `[p2,p3]` ↔ `[p1,p2]` — page p2 is familiar.
