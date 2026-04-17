PreToolUse:Read hook additional context: <context_guidance>
  <tip>
    Read is the right default. Use offset/limit to scope large files.
    Only reach for capy_execute_file when the file is genuinely large (10k+ lines)
    AND you want a derived answer (count, stats, extracted pattern), not the content itself.
    If an Edit will follow, just Read — capy_execute_file beforehand is pure overhead.
  </tip>
</context_guidance>
