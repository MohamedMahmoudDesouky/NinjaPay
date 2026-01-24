-- k8s/base/init.sql
CREATE DATABASE IF NOT EXISTS bookstore;
USE bookstore;

CREATE TABLE IF NOT EXISTS books (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  author VARCHAR(255) NOT NULL,
  isbn VARCHAR(20),
  price DECIMAL(10,2),
  stock INT DEFAULT 10,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Optional: Insert sample data
INSERT INTO books (title, author, isbn, price, stock) VALUES
  ('The Pragmatic Programmer', 'David Thomas, Andrew Hunt', '978-0135957059', 49.99, 25),
  ('Clean Code', 'Robert C. Martin', '978-0132350884', 39.99, 30),
  ('Design Patterns', 'Gang of Four', '978-0201633610', 54.99, 15),
  ('Kubernetes in Action', 'Marko Luksa', '978-1617293726', 59.99, 20),
  ('Docker Deep Dive', 'Nigel Poulton', '978-1521822807', 29.99, 35),
  ('OpenShift for Developers', 'Grant Shipley', '978-1491961438', 44.99, 18),
  ('Site Reliability Engineering', 'Google SRE Team', '978-1491929124', 49.99, 22),
  ('The DevOps Handbook', 'Gene Kim et al.', '978-1942788003', 34.99, 28)
ON DUPLICATE KEY UPDATE id = id;