---
description: Start tracking a new feature for blog prompts
---

Run the start-feature.sh script with the provided feature name. Pass all arguments after the command to the script.

For example, if the user types `/start-feature Add dark mode toggle`, you should run:

```bash
bash scripts/start-feature.sh {{ARGS}}
```

After running the script, inform the user that the feature tracking has started and all subsequent prompts will be automatically recorded.
