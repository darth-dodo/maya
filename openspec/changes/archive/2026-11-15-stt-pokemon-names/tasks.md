# Tasks

## 1. Vocabulary (tests first)

- [x] 1.1 `Maya.Voice.Vocabulary.bias_terms/2` and the cached `names/0`; `GameData.import!/1` erases the cache; verify the vocabulary tests (order, dedup, cap, size)
- [x] 1.2 `scripts/english_guard.exs` and `priv/data/english_guard.txt`; verify the guard holds "rails", "golden", "electric", "around"
- [x] 1.3 `Maya.Voice.Vocabulary.correct/2`; verify the real misses and the English negatives

## 2. Voice loop (tests first)

- [x] 2.1 `STT.transcribe/3` sends one `context_bias` field per term; verify the multipart test asserts the fields and their size
- [ ] 2.2 Conversation reads Progress in the STT stage, corrects the transcript and passes Progress to the agent; verify the Conversation test that stores the corrected Question

## 3. Gates

- [ ] 3.1 Run `factory:test`; verify every gate is green and the coverage floor is not lowered

## Workflow follow-up

- Archive with `openspec-archive-change stt-pokemon-names` in the same PR.
- Abhishek: on the phone, "Where do I catch a Ralts?" and "What is Torchic weak to?" transcribe correctly 5 times out of 5; paste the STT stage numbers from the Supabase query on #40 before and after.
