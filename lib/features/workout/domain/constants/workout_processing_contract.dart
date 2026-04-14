const int kClientMetricsVersion = 1;

const String kClientRecordingStatus = 'client_recording';
const String kClientPendingProcessingStatus =
    'client_finished_pending_processing';
const String kClientFinalizedStatus = 'client_finalized';

const String kClientProcessingStatus = kClientPendingProcessingStatus;

const String kDeterministicFinalizeJobType = 'deterministic_finalize';
const String kQueuedJobStatus = 'queued';

const String kClientFinishEnqueuedEvent = 'client_finish_enqueued';
const String kClientFinishEnqueuedMessage =
    'Client queued deterministic processing after workout stop.';
