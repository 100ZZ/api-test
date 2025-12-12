-- Add assertion_results column to execution_records if missing
ALTER TABLE execution_records
  ADD COLUMN IF NOT EXISTS assertion_results JSON NULL AFTER error_message;

