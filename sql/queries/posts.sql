-- name: GetPost :one
SELECT * FROM posts
WHERE id = $1 LIMIT 1;

-- name: ListPosts :many
SELECT * FROM posts
ORDER BY name;

-- name: ListPostsByUser :many
SELECT * FROM posts
WHERE user_id = $1
ORDER BY posts.name;

-- name: CreatePost :one
INSERT INTO posts (
  user_id, name
) VALUES (
  $1, $2
)
RETURNING *;

-- name: DeletePost :exec
DELETE FROM posts
WHERE id = $1;