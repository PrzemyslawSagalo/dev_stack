local python_utils = {}

function python_utils.python_interpreter_path()
    local python_interpreter_path = os.getenv('PYTHON_INTERPRETER_PATH')
    return python_interpreter_path
end

function python_utils.python_path()
    local full_python_path = os.getenv('PYTHONPATH')
    return full_python_path
end

return python_utils

