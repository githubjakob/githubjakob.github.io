---
layout: post
slug: sql-alchemy-update-or-create-upsert
title: "wip"
published: false
---

Some time ago we had to implement a multi thread safe upsert function in SqlAlchemy.


Unfortunately SqlAlchemy does not provide one out of the box so we had to come up with a custom solution.

In this blog post I want to explore the different options and explain the solution that we settled with.





| Approach                            | Problem                                                                                   |
|-------------------------------------|-------------------------------------------------------------------------------------------|
| with_update                         | does not work when the row to be updated does not exist yet                               |
| on_conflict_do_update               | leaving ORM level (therefore, no update of relationships, problems with inherited models) |
| Postgres Advisory Lock / Lock table | the other transaction will not wait but fail, manual retry needed                         |
| Isolation Level SERIALIZABLE        | can only be configured when the session is started  degenerated performance               |
| try-except block                    | thinking                                                                                  |