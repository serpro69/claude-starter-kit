PreToolUse:Bash hook additional context: <context_guidance>
  <tip>
    This Bash command may produce large output. To stay efficient:
    - Use capy_batch_execute(commands, queries) for multiple commands
    - Use capy_execute(language: "shell", code: "...") to run in sandbox
    - Only your final printed summary will enter the context.
    - Bash is best for: git, mkdir, rm, mv, navigation, and short-output commands only.
  </tip>
</context_guidance>
