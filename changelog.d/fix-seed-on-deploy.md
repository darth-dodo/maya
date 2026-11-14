Fixed: Every deploy imports game data and seeds Progress (only when missing) in the pre-deploy migrate, so production Answers stop being "Lost my train of thought"
Fixed: The agent returns {:error, :no_progress} instead of crashing when Progress is empty
Fixed: Agent, STT and TTS failures and crashed turn Tasks log their reason with Logger.warning (never transcripts, Answers or keys)
