import 'package:powersync/powersync.dart';

const schema = Schema(([
  //class: Activity
  Table('activity', [
    Column.text('workspaceId'),
    Column.text('boardId'),
    Column.text('userId'),
    Column.text('cardId'),
    Column.text('description'),
    Column.text('dateCreated'),
  ], indexes: [
    Index('board', [IndexedColumn('boardId')]),
    Index('user', [IndexedColumn('userId')]),
    Index('card', [IndexedColumn('cardId')])
  ]),
  //class: Attachment
  Table('attachment', [
    Column.text('workspaceId'),
    Column.text('userId'),
    Column.text('cardId'),
    Column.text('attachment'),
  ], indexes: [
    Index('user', [IndexedColumn('userId')]),
  ]),
  //class: Board
  Table('board', [
    Column.text('workspaceId'),
    Column.text('userId'),
    Column.text('name'),
    Column.text('description'),
    Column.text('visibility'),
    Column.text('background'),
    Column.integer('starred'),
    Column.integer('enableCover'),
    Column.integer('watch'),
    Column.integer('availableOffline'),
    Column.text('label'),
    Column.text('emailAddress'),
    Column.integer('commenting'),
    Column.integer('memberType'),
    Column.integer('pinned'),
    Column.integer('selfJoin'),
    Column.integer('close'),
  ], indexes: [
    Index('workspace', [IndexedColumn('workspaceId')]),
    Index('user', [IndexedColumn('userId')]),
  ]),
  //class: Cardlist
  Table('card', [
    Column.text('workspaceId'),
    Column.text('listId'),
    Column.text('userId'),
    Column.text('name'),
    Column.text('description'),
    Column.text('startDate'),
    Column.text('dueDate'),
    Column.integer('rank'),
    Column.integer('attachment'),
    Column.integer('archived'),
    Column.integer('checklist'),
    Column.integer('comments'),
  ], indexes: [
    Index('list', [IndexedColumn('listId')]),
    Index('user', [IndexedColumn('userId')]),
  ]),
  //class: Checklist
  Table('checklist', [
    Column.text('workspaceId'),
    Column.text('cardId'),
    Column.text('name'),
    Column.integer('status'),
  ], indexes: [
    Index('card', [IndexedColumn('cardId')]),
  ]),
  //class: Comment
  Table('comment', [
    Column.text('workspaceId'),
    Column.text('cardId'),
    Column.text('userId'),
    Column.text('description'),
  ], indexes: [
    Index('card', [IndexedColumn('cardId')]),
    Index('user', [IndexedColumn('userId')]),
  ]),
  //class: Listboard
  Table('listboard', [
    Column.text('workspaceId'),
    Column.text('boardId'),
    Column.text('userId'),
    Column.text('name'),
    Column.integer('archived'),
    Column.integer('listOrder'),
  ], indexes: [
    Index('board', [IndexedColumn('boardId')]),
    Index('user', [IndexedColumn('userId')]),
  ]),
  //class: Member
  Table('member', [
    Column.text('workspaceId'),
    Column.text('userId'),
    Column.text('name'),
    Column.text('role'),
  ], indexes: [
    Index('user', [IndexedColumn('userId')]),
  ]),
  //class: User
  // table: trellouser
  // fields:
  //   name: String?
  //   email: String
  //   password: String
  Table('trellouser', [
    Column.text('name'),
    Column.text('email'),
    Column.text('password'),
  ], indexes: [
    Index('email', [IndexedColumn('email')]),
  ]),
  //class: Workspace
  Table('workspace', [
    Column.text('userId'),
    Column.text('name'),
    Column.text('description'),
    Column.text('visibility'),
  ], indexes: [
    Index('user', [IndexedColumn('userId')]),
  ]),
  // class: BoardLabel
  Table('board_label', [
    Column.text('boardId'),
    Column.text('workspaceId'),
    Column.text('title'),
    Column.text('color'),
    Column.text('dateCreated'),
  ], indexes: [
    Index('board', [IndexedColumn('boardId')]),
  ]),
  // class: CardLabel
  Table('card_label', [
    Column.text('cardId'),
    Column.text('boardLabelId'),
    Column.text('boardId'),
    Column.text('workspaceId'),
    Column.text('dateCreated'),
  ], indexes: [
    Index('card', [IndexedColumn('cardId')]),
  ])
]));
