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

const String kGpsStreamErrorEvent = 'gps_stream_error';
const String kGpsStreamErrorMessage =
    'Client GPS stream emitted an error during recording.';

const String kGpsStreamDoneEvent = 'gps_stream_done';
const String kGpsStreamDoneMessage =
    'Client GPS stream ended unexpectedly during recording.';

const String kGpsStreamStalledEvent = 'gps_stream_stalled';
const String kGpsStreamStalledMessage =
    'Client GPS stream stalled without fresh location updates.';

const String kGpsRecoveryStartedEvent = 'gps_recovery_started';
const String kGpsRecoveryStartedMessage =
    'Client started GPS stream recovery.';

const String kGpsRecoverySucceededEvent = 'gps_recovery_succeeded';
const String kGpsRecoverySucceededMessage =
    'Client GPS stream recovery succeeded.';

const String kGpsRecoveryFailedEvent = 'gps_recovery_failed';
const String kGpsRecoveryFailedMessage =
    'Client GPS stream recovery failed.';
