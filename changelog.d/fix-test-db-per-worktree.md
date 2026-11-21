Fixed: parallel builders no longer deadlock on a shared test database, since each git worktree tests on its own `maya_test_<worktree>` database by default
