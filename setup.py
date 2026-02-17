from setuptools import setup
from Cython.Build import cythonize

setup(
    name="my_async",
    ext_modules=cythonize("src/*.pyx", language_level=3),
    zip_safe=False,
)