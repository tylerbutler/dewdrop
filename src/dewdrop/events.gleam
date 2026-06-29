//// Fluid (Socket.IO) event-name vocabulary.
////
//// Dependency-free constants shared by every dewdrop codec (the aquamarine
//// client codec, the beryl server codec) and by downstream protocol packages
//// such as spillway. Kept separate from `dewdrop` so importers get the event
//// names without pulling in aquamarine or beryl.

/// Outbound: client pushes `connect_document` to begin collaboration.
pub const connect_document = "connect_document"

/// Inbound: server acknowledges a successful `connect_document`.
pub const connect_document_success = "connect_document_success"

/// Inbound: server rejects a `connect_document` attempt.
pub const connect_document_error = "connect_document_error"

/// Outbound: client submits ops.
pub const submit_op = "submitOp"

/// Outbound: client submits signals.
pub const submit_signal = "submitSignal"

/// Inbound: sequenced ops from the server.
pub const op = "op"

/// Inbound: signals from the server.
pub const signal = "signal"

/// Inbound: rejected ops.
pub const nack = "nack"

/// Connection close event.
pub const close = "close"

/// Outbound: client submits a summary/snapshot for the document.
pub const submit_summary = "submitSummary"

/// Inbound: server acknowledges an accepted summary.
pub const summary_ack = "summaryAck"

/// Inbound: server rejects a summary.
pub const summary_nack = "summaryNack"
