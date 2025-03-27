from concurrent.futures import ThreadPoolExecutor, TimeoutError
from functools import wraps


def timeout(seconds):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            with ThreadPoolExecutor() as executor:
                future = executor.submit(func, *args, **kwargs)
                try:
                    return future.result(timeout=seconds)
                except TimeoutError:
                    raise TimeoutError(
                        f"Function {func.__name__} timed out after {seconds} seconds!"
                    )

        return wrapper

    return decorator
