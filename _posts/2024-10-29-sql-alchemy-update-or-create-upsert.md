---
layout: post
slug: sql-alchemy-update-or-create-upsert
title: "SQLAlchemy Upserts in PostgreSQL: Conquering Concurrency Challenges for Your Flask API"
draft: true
---


Recently my team and I had to implement an "update or create" (or upsert) function with SqlAlchemy (using PostgreSQL) for a Flask API that can be safely called with multiple concurrent requests.

![Not sure Meme](/assets/images/update-or-insert.jpg)

Since SqlAlchemy does not support “upsert” out-of-the-box, this was an interesting challenge and revealed some interesting details about concurrency control with SqlAlchemy and PostgreSQL.

In the end, we settled for a solution implementing "optimistic concurrency control" using a simple try-catch.

You can find the code below, and the [full working demo Flask application with the solution in my Github repo](https://github.com/githubjakob/flask-sqlalchemy-upsert).

## The “naive approach”

Let’s start with the naive approach and the problem:

```
query = db.session.query(model).filter(and_(*filters))
existing_model = query.one_or_none()

if existing_model:
    model = create_data_model
    model.id = existing_model.id
    model = db.session.merge(model)
else:
    model = create_data_model
    db.session.add(model)
```

After running with this code for a while in production, our error reporting in Sentry started to show this error.

```
sqlalchemy.exc.IntegrityError: (psycopg2.errors.UniqueViolation) duplicate key value violates unique constraint
```

![Jackie Chan But Why Meme](/assets/images/jackie-chan-meme.gif)

## What is going on?

It turned out that sometimes we received API requests that caused updates for the same key “at the same time”, triggering a race condition in our implementation.

Analyzing the problem revelead that our upsert implementation was not thread-safe. 

In our case, two transactions would concurrently SELECT and INSERT data for the same key, causing the issue when both transactions first SELECT and return no data, and then both transactions INSERT.


| T1                  | T2                           |
|---------------------|------------------------------|
| SELECT returns None |                              |
|                     | SELECT returns None          |
| INSERT              |                              |
| commit              |                              |
|                     | INSERT                       |       
|                     | unique constraint violation  |



## But… ACID??

This situation left us initially quite confused, since we understood the [ACID properties](https://en.wikipedia.org/wiki/ACID) completely wrong.

![Well Yes Meme](/assets/images/well-yes-meme.png)

The first approach of one of our developers was to explicitly start a transaction before the SELECT, under the wrong assumption that the ATOMICITY property of the transactions would imply that all operations within one transactions running in one unit.

As it turns out, ATOMICITY here only means that transactions either have an effect or not - all, or nothing.  

ATOMICITY does not mean that all operations within one transaction happen in one atomic block without any interference from other transactions

What we are dealing here with is rather an issue of the I in ACID: ISOLATION.

In the default PostgreSQL isolation level `read-committed` you cannot expect that during the time of a transaction 
multiple reads return the same data.

So we have to look out for another solution.


## Alternative implementation with SqlAlchemy

There are [several](https://stackoverflow.com/questions/7165998/how-to-do-an-upsert-with-sqlalchemy) [questions](https://stackoverflow.com/questions/74429898/sqlalchemy-insert-or-update-upsert-using-orm-session) [on Stackoverflow](https://stackoverflow.com/questions/41724658/how-to-do-a-proper-upsert-using-sqlalchemy-on-postgresql) discussing the topic. But none offered a really satisfying solution.

After some research, we gathered the different solutions that we could find and weighted their various pros and cons.


| Type                           | Approach                            | Assessment                                                                            |
|--------------------------------|-------------------------------------|---------------------------------------------------------------------------------------|
| pessimistic, row level locking | `with_for_update`                   | does not work when the row to be updated does not exist yet                           |
| optimistic update              | on_conflict_do_update               | leaving ORM level (therefore, no update of relationships, problems with inherited models) |
| pessimistic, locking           | PostgreSQL Advisory Lock / Lock table | the other transaction will not wait but fail, manual retry needed                     |
| Change DB Isolation Level      |                                     | can only be configured when the session is started, degenerated performance           |
| optimistic update              | try-except block                    |                                                                                       |


## The final version

In the end, we settled for the “optimistic concurrency control” version of a solution with a relatively simple try-catch.

The rough idea is to optimistically perform the SELECT and INSERT (same as in the naive solution), 
but to catch the `IntegrityError` if the race condition occurs and then perform an UPDATE.

Two things to highlight:

- When the `IntegrityError` is thrown, we need to rollback the transaction. In order to avoid that we rollback the entire 
transaction, we can use a nested transaction and only rollback the part that is related to the upsert that caused the `IntegrityError`.

- When the `IntegrityError` is thrown, we want to ensure that we only perform the update when we encountered the right `UniqueViolation`
and not some other violation related to the model we are about to insert, e.g. violating some other non-null constraint. For this we 
can parse the exception inside `IntegrityError` and check that it contains the names of the columns we used as keys - not super nice, but it works. 

Here is the core part of our solution ([for full code see my Github repo](https://github.com/githubjakob/flask-sqlalchemy-upsert/blob/eb36dc189890bb8cf89eb6ff1e1c705f8c4f4765/repository.py#L93)):

```
query = db.session.query(self.model).filter(and_(*filters))
existing_model = query.one_or_none()

checkpoint = db.session.begin_nested()

if existing_model:
    model = self._merge_models(existing_model, create_data_model)
else:
    model = create_data_model
    db.session.add(model)

try:
    # Attempt to upsert in a nested transaction
    checkpoint.commit()
except IntegrityError as e:
    # Catching the constraint violation in case of a race condition
    # which can happen when transaction A attempts to create the model
    # while transaction B just did create it
    # in which case we rollback the attempt, and then re-try with a merge
    checkpoint.rollback()

    # we only re-try if it failed for the right reason
    if not self._is_matching_unique_constraint_violation(e):
        raise e

    existing_model = query.one()
    model = self._merge_models(existing_model, create_data_model)
```
