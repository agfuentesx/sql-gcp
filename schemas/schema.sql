CREATE TABLE IF NOT EXISTS companies (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_companies_name (name)
);

CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    company_id INT,
    UNIQUE KEY uq_employee (first_name, last_name, company_id),
    CONSTRAINT fk_employees_company FOREIGN KEY (company_id) REFERENCES companies(id)
);

INSERT IGNORE INTO companies (name) VALUES ('TechCorp'), ('DevOpsInc');

INSERT IGNORE INTO employees (first_name, last_name, company_id)
SELECT s.first_name, s.last_name, c.id
FROM (
    SELECT 'John' AS first_name, 'Doe' AS last_name, 'TechCorp' AS company_name
    UNION ALL SELECT 'Jane', 'Smith', 'TechCorp'
    UNION ALL SELECT 'Alice', 'Johnson', 'DevOpsInc'
) AS s
JOIN companies c ON c.name = s.company_name;

CREATE OR REPLACE VIEW v_employees_by_company AS
SELECT
    e.first_name,
    e.last_name,
    c.name AS company_name
FROM
    employees e
JOIN
    companies c ON e.company_id = c.id
ORDER BY
    e.first_name ASC;