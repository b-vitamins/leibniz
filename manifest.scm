(specifications->manifest
 '(;; System tools
   "python"
   "git"
   "make"
   "curl"
   "jq"
   "netcat-openbsd"  ; for port checking
   
   ;; Python packages from myguix channel
   "python-neo4j"
   "python-qdrant-client"
   "python-meilisearch"
   
   ;; Core Python packages
   "python-fastapi"
   "python-uvicorn"
   "python-redis"
   "python-httpx"
   "python-pydantic"
   "python-pydantic-settings"
   "python-numpy"
   "python-rich"
   "python-typer"
   "python-openai"
   
   ;; Development tools
   "poetry"
   "python-pytest"
   "python-pytest-cov"
   "python-pytest-asyncio"
   "python-pytest-benchmark"
   "python-pytest-xdist"
   "python-black"
   "python-mypy"
   "python-ruff"
   "python-locust"
   
   ;; Type stubs for mypy
   "python-types-requests"
   
   ;; Documentation tools (optional)
   "python-sphinx"
   "python-sphinx-autodoc-typehints"
   
   ;; Additional useful tools
   "python-pyclean"))