# Python

Using version 3.8.3 (the version I happened to have locally)

## Running it locally

### Dependencies

While developing locally, I'm using a virtual environment to help manage the dependencies without mixing them up with any other local Python projects. See https://docs.python.org/3/tutorial/venv.html

You should 'activate' the virtual environment before installing dependencies, so that they are installed in the virtual environment.

```bash
# be in the python folder
cd python

# create a virtual environment in the directory .venv
python3 -m venv .venv

# activate it
source .venv/bin/activate
```

With an activated environment you can then run

- `pip install` to install any new dependencies in the activated environment
- `python -m pip freeze > requirements.txt` to create a record of the dependencies and their versions
- And crucially, you can tell pip to read the requirements.txt to install all the correct dependencies, using `python -m pip install -r requirements.txt`. This makes life easier because you verify that you're working in a similar/identical environment as your collaborators/the deployment, reducing the likelihood of unreproducable bugs; and it means we can have a single source of truth when we want to programmatically install all the correct versions of things.


