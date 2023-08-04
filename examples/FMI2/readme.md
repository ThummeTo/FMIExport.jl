## Important

If you are using packages in `dev`-mode as dependencies for a FMU to build, it is required to add them via **absolute path** to the project and manifest. 
Example: `dev "C:/users/.../MyDevPackage"`.
This is because the original package is copied into a temporary directory and slightly modified. 
