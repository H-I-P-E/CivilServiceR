# Python

Using version 3.8.3 (the version I happened to have locally)

## Local development

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

### Environment variables

I am using the dotenv library to manage environment variables locally and avoid them conflicting with environment variables in other projects. I don't know how well this translates to the deployment environment.

.env.example shows which environment variables you'll need. You can copy this file into a new file .env and fill in the values.

How to access an environment variable in python:

```python
from dotenv import load_dotenv
load_dotenv()
import os
MY_SECRET_KEY = os.getenv("NAME_OF_KEY")
```

#### For AWS

To access AWS programmatically, you'll be directed by their documentation to (either automatically or manually) update your `~/.aws/credentials`. But the default way of doing this will cause conflicts with any other AWS projects you are doing. Although you can store more than one profile in `~/.aws/credentials`, as [here](https://docs.aws.amazon.com/sdk-for-php/v3/developer-guide/guide_credentials_profiles.html), it's going to be simplest to store these keys as regular environment variables like above.
