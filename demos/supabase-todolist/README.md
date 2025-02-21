# PowerSync + Supabase Flutter Demo: Todo List App

Demo app demonstrating use of the PowerSync SDK for Flutter together with Supabase. For a step-by-step guide, see [here](https://docs.powersync.com/integration-guides/supabase).

# Running the app

Ensure you have [melos](https://melos.invertase.dev/~melos-latest/getting-started) installed.

1. `cd demos/supabase-todolist`
2. `melos prepare`
3. `cp lib/app_config_template.dart lib/app_config.dart`
4. Insert your Supabase and PowerSync project credentials into `lib/app_config.dart` (See instructions below)
5. `flutter run`

# Set up Supabase Project

Create a new Supabase project, and paste an run the contents of [database.sql](./database.sql) in the Supabase SQL editor.

It does the following:

1. Create `lists` and `todos` tables.
2. Create a publication called `powersync` for `lists` and `todos`.
3. Enable row level security, allowing users to only view and edit their own data.
4. Create a trigger to populate some sample data when an user registers.

# Set up PowerSync Instance

Create a new PowerSync instance, connecting to the database of the Supabase project.

Then deploy the following sync rules:

```yaml
bucket_definitions:
  user_lists:
    priority: 1
    parameters: select id as list_id from lists where owner_id = request.user_id()
    data:
      - select * from lists where id = bucket.list_id

  user_todos:
    parameters: select id as list_id from lists where owner_id = request.user_id()
    data:
      - select * from todos where list_id = bucket.list_id
```

The rules synchronize list with a higher priority the items within the list. This can be
useful to keep the list overview page reactive during a large sync cycle affecting many
rows in the `user_todos` bucket. The two buckets can also be unified into a single one if
priorities are not important (the app will work without changes):

```yaml
bucket_definitions:
  user_lists:
    # Separate bucket per todo list
    parameters: select id as list_id from lists where owner_id = request.user_id()
    data:
      - select * from lists where id = bucket.list_id
      - select * from todos where list_id = bucket.list_id
```

# Configure the app

Insert the credentials of your new Supabase and PowerSync projects into `lib/app_config.dart`
