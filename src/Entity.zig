//! An entity index.
//! They are created using the `Entities` struct.
//! They are used as indices with `Components` structs.
//!
//! Entities are conceptual "things" which possess attributes (Components).
//! As an exemple, a Car (Entity) has a Color (Component), a Position
//! (Component) and a Speed (Component).
index: u32,
generation: u32,
