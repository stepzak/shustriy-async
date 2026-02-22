from setuptools import setup, find_packages
from Cython.Build import cythonize
import os

pyx_files = []
for root, dirs, files in os.walk("src"):
    for file in files:
        if file.endswith(".pyx"):
            module_path = os.path.join(root, file)
            module_name = (
                module_path
                .replace("src/", "")
                .replace("/", ".")
                .replace(".pyx", "")
            )
            pyx_files.append((module_name, [module_path]))

setup(
    name="shustriy-async",
    version="0.2.0",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    ext_modules=cythonize(
        [mod[1][0] for mod in pyx_files],
        compiler_directives={'language_level': "3"}
    ),
    zip_safe=False,
)