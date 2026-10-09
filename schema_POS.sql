//MIGRATION
CREATE DATABASE IF NOT EXISTS pos_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE pos_db;

-- =========================================================
-- 1. ROLES
-- =========================================================
CREATE TABLE roles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255) NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;


-- =========================================================
-- 2. USERS
-- =========================================================
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(30) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_users_role
        FOREIGN KEY (role_id) REFERENCES roles(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- =========================================================
-- 3. CATEGORIES
-- =========================================================
CREATE TABLE categories (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_categories_name (name)
) ENGINE=InnoDB;


-- =========================================================
-- 4. UNITS
-- =========================================================
CREATE TABLE units (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    abbreviation VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_units_name (name),
    UNIQUE KEY uk_units_abbreviation (abbreviation)
) ENGINE=InnoDB;


-- =========================================================
-- 5. SUPPLIERS
-- =========================================================
CREATE TABLE suppliers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    phone VARCHAR(30) NULL,
    email VARCHAR(100) NULL,
    address TEXT NULL,
    contact_person VARCHAR(100) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;


-- =========================================================
-- 6. CUSTOMERS
-- =========================================================
CREATE TABLE customers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    phone VARCHAR(30) NULL,
    email VARCHAR(100) NULL,
    address TEXT NULL,
    customer_type ENUM('GENERAL','MEMBER','VIP') NOT NULL DEFAULT 'GENERAL',
    points INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;


-- =========================================================
-- 7. PRODUCTS
-- =========================================================
CREATE TABLE products (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_id BIGINT UNSIGNED NOT NULL,
    unit_id BIGINT UNSIGNED NOT NULL,

    sku VARCHAR(50) NOT NULL UNIQUE,
    barcode VARCHAR(100) NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    purchase_price DECIMAL(15,2) NOT NULL DEFAULT 0,
    selling_price DECIMAL(15,2) NOT NULL DEFAULT 0,

    min_stock DECIMAL(15,3) NOT NULL DEFAULT 0,
    max_stock DECIMAL(15,3) NULL,

    tax_rate DECIMAL(5,2) NOT NULL DEFAULT 0,

    image VARCHAR(255) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES categories(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_products_unit
        FOREIGN KEY (unit_id) REFERENCES units(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    INDEX idx_products_name (name),
    INDEX idx_products_barcode (barcode),
    INDEX idx_products_category (category_id)
) ENGINE=InnoDB;


-- =========================================================
-- 8. STOCKS
-- =========================================================
CREATE TABLE stocks (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT UNSIGNED NOT NULL,

    quantity DECIMAL(15,3) NOT NULL DEFAULT 0,
    reserved_quantity DECIMAL(15,3) NOT NULL DEFAULT 0,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_stocks_product (product_id),

    CONSTRAINT fk_stocks_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB;


-- =========================================================
-- 9. PURCHASES
-- =========================================================
CREATE TABLE purchases (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    invoice_number VARCHAR(50) NOT NULL UNIQUE,
    supplier_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,

    purchase_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    subtotal DECIMAL(15,2) NOT NULL DEFAULT 0,
    discount DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax DECIMAL(15,2) NOT NULL DEFAULT 0,
    grand_total DECIMAL(15,2) NOT NULL DEFAULT 0,

    paid_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    due_amount DECIMAL(15,2) NOT NULL DEFAULT 0,

    payment_status ENUM(
        'PAID',
        'PARTIAL',
        'UNPAID'
    ) NOT NULL DEFAULT 'UNPAID',

    status ENUM(
        'DRAFT',
        'COMPLETED',
        'CANCELLED'
    ) NOT NULL DEFAULT 'DRAFT',

    notes TEXT NULL,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_purchases_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_purchases_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    INDEX idx_purchases_date (purchase_date),
    INDEX idx_purchases_supplier (supplier_id)
) ENGINE=InnoDB;


-- =========================================================
-- 10. PURCHASE DETAILS
-- =========================================================
CREATE TABLE purchase_details (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    purchase_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,

    quantity DECIMAL(15,3) NOT NULL,
    purchase_price DECIMAL(15,2) NOT NULL,

    discount DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax DECIMAL(15,2) NOT NULL DEFAULT 0,
    subtotal DECIMAL(15,2) NOT NULL DEFAULT 0,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_purchase_details_purchase
        FOREIGN KEY (purchase_id) REFERENCES purchases(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_purchase_details_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    INDEX idx_purchase_details_product (product_id)
) ENGINE=InnoDB;


-- =========================================================
-- 11. SALES
-- =========================================================
CREATE TABLE sales (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    invoice_number VARCHAR(50) NOT NULL UNIQUE,

    customer_id BIGINT UNSIGNED NULL,
    user_id BIGINT UNSIGNED NOT NULL,

    sale_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    subtotal DECIMAL(15,2) NOT NULL DEFAULT 0,
    discount DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax DECIMAL(15,2) NOT NULL DEFAULT 0,

    grand_total DECIMAL(15,2) NOT NULL DEFAULT 0,

    paid_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    change_amount DECIMAL(15,2) NOT NULL DEFAULT 0,

    payment_method ENUM(
        'CASH',
        'DEBIT',
        'CREDIT_CARD',
        'QRIS',
        'TRANSFER',
        'EWALLET'
    ) NOT NULL DEFAULT 'CASH',

    payment_status ENUM(
        'PAID',
        'PARTIAL',
        'UNPAID'
    ) NOT NULL DEFAULT 'PAID',

    status ENUM(
        'DRAFT',
        'COMPLETED',
        'CANCELLED',
        'REFUNDED'
    ) NOT NULL DEFAULT 'DRAFT',

    notes TEXT NULL,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_sales_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_sales_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    INDEX idx_sales_date (sale_date),
    INDEX idx_sales_customer (customer_id),
    INDEX idx_sales_user (user_id)
) ENGINE=InnoDB;


-- =========================================================
-- 12. SALES DETAILS
-- =========================================================
CREATE TABLE sale_details (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    sale_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,

    quantity DECIMAL(15,3) NOT NULL,
    selling_price DECIMAL(15,2) NOT NULL,

    discount DECIMAL(15,2) NOT NULL DEFAULT 0,
    discount_percent DECIMAL(5,2) NOT NULL DEFAULT 0,

    tax DECIMAL(15,2) NOT NULL DEFAULT 0,

    subtotal DECIMAL(15,2) NOT NULL DEFAULT 0,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_sale_details_sale
        FOREIGN KEY (sale_id) REFERENCES sales(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_sale_details_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    INDEX idx_sale_details_product (product_id)
) ENGINE=InnoDB;


-- =========================================================
-- 13. PAYMENTS
-- =========================================================
CREATE TABLE payments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    sale_id BIGINT UNSIGNED NOT NULL,

    payment_method ENUM(
        'CASH',
        'DEBIT',
        'CREDIT_CARD',
        'QRIS',
        'TRANSFER',
        'EWALLET'
    ) NOT NULL,

    amount DECIMAL(15,2) NOT NULL,

    reference_number VARCHAR(100) NULL,

    payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    notes VARCHAR(255) NULL,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_payments_sale
        FOREIGN KEY (sale_id) REFERENCES sales(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    INDEX idx_payments_sale (sale_id)
) ENGINE=InnoDB;


-- =========================================================
-- 14. STOCK MOVEMENTS
-- =========================================================
CREATE TABLE stock_movements (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    product_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NULL,

    type ENUM(
        'PURCHASE',
        'SALE',
        'SALE_RETURN',
        'PURCHASE_RETURN',
        'ADJUSTMENT_IN',
        'ADJUSTMENT_OUT',
        'INITIAL'
    ) NOT NULL,

    reference_id BIGINT UNSIGNED NULL,
    reference_number VARCHAR(100) NULL,

    quantity DECIMAL(15,3) NOT NULL,

    stock_before DECIMAL(15,3) NOT NULL DEFAULT 0,
    stock_after DECIMAL(15,3) NOT NULL DEFAULT 0,

    notes TEXT NULL,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_stock_movements_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_stock_movements_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    INDEX idx_stock_movements_product (product_id),
    INDEX idx_stock_movements_type (type),
    INDEX idx_stock_movements_date (created_at)
) ENGINE=InnoDB;


-- =========================================================
-- 15. SALES RETURNS
-- =========================================================
CREATE TABLE sales_returns (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    return_number VARCHAR(50) NOT NULL UNIQUE,

    sale_id BIGINT UNSIGNED NOT NULL,
    customer_id BIGINT UNSIGNED NULL,
    user_id BIGINT UNSIGNED NOT NULL,

    return_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    total_amount DECIMAL(15,2) NOT NULL DEFAULT 0,

    refund_method ENUM(
        'CASH',
        'TRANSFER',
        'STORE_CREDIT',
        'REPLACE'
    ) NOT NULL DEFAULT 'CASH',

    reason TEXT NULL,

    status ENUM(
        'DRAFT',
        'COMPLETED',
        'CANCELLED'
    ) NOT NULL DEFAULT 'DRAFT',

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_sales_returns_sale
        FOREIGN KEY (sale_id) REFERENCES sales(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_sales_returns_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_sales_returns_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- =========================================================
-- 16. SALES RETURN DETAILS
-- =========================================================
CREATE TABLE sales_return_details (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    sales_return_id BIGINT UNSIGNED NOT NULL,
    sale_detail_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,

    quantity DECIMAL(15,3) NOT NULL,
    price DECIMAL(15,2) NOT NULL,

    subtotal DECIMAL(15,2) NOT NULL DEFAULT 0,

    reason VARCHAR(255) NULL,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sales_return_details_return
        FOREIGN KEY (sales_return_id) REFERENCES sales_returns(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_sales_return_details_sale_detail
        FOREIGN KEY (sale_detail_id) REFERENCES sale_details(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_sales_return_details_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- =========================================================
-- 17. PURCHASE RETURNS
-- =========================================================
CREATE TABLE purchase_returns (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    return_number VARCHAR(50) NOT NULL UNIQUE,

    purchase_id BIGINT UNSIGNED NOT NULL,
    supplier_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,

    return_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    total_amount DECIMAL(15,2) NOT NULL DEFAULT 0,

    reason TEXT NULL,

    status ENUM(
        'DRAFT',
        'COMPLETED',
        'CANCELLED'
    ) NOT NULL DEFAULT 'DRAFT',

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_purchase_returns_purchase
        FOREIGN KEY (purchase_id) REFERENCES purchases(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_purchase_returns_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_purchase_returns_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- =========================================================
-- 18. PURCHASE RETURN DETAILS
-- =========================================================
CREATE TABLE purchase_return_details (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    purchase_return_id BIGINT UNSIGNED NOT NULL,
    purchase_detail_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,

    quantity DECIMAL(15,3) NOT NULL,
    price DECIMAL(15,2) NOT NULL,

    subtotal DECIMAL(15,2) NOT NULL DEFAULT 0,

    reason VARCHAR(255) NULL,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_purchase_return_details_return
        FOREIGN KEY (purchase_return_id) REFERENCES purchase_returns(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_purchase_return_details_purchase_detail
        FOREIGN KEY (purchase_detail_id) REFERENCES purchase_details(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_purchase_return_details_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- =========================================================
-- 19. EXPENSES
-- =========================================================
CREATE TABLE expenses (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,

    expense_number VARCHAR(50) NOT NULL UNIQUE,
    expense_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    category VARCHAR(100) NOT NULL,
    description TEXT NULL,

    amount DECIMAL(15,2) NOT NULL,

    payment_method ENUM(
        'CASH',
        'TRANSFER',
        'DEBIT',
        'CREDIT_CARD',
        'QRIS'
    ) NOT NULL DEFAULT 'CASH',

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_expenses_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    INDEX idx_expenses_date (expense_date)
) ENGINE=InnoDB;


-- =========================================================
-- 20. CASHIER SESSIONS
-- =========================================================
CREATE TABLE cashier_sessions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,

    opened_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at DATETIME NULL,

    opening_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    closing_balance DECIMAL(15,2) NULL,

    expected_balance DECIMAL(15,2) NULL,
    difference DECIMAL(15,2) NULL,

    status ENUM(
        'OPEN',
        'CLOSED'
    ) NOT NULL DEFAULT 'OPEN',

    notes TEXT NULL,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_cashier_sessions_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    INDEX idx_cashier_sessions_user (user_id),
    INDEX idx_cashier_sessions_status (status)
) ENGINE=InnoDB;


-- =========================================================
-- 21. SETTINGS
-- =========================================================
CREATE TABLE settings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT NULL,
    description VARCHAR(255) NULL,

    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

//SEEDER
-- Roles
INSERT INTO roles (name, description) VALUES
('ADMIN', 'Administrator sistem'),
('MANAGER', 'Manager toko'),
('CASHIER', 'Kasir'),
('WAREHOUSE', 'Petugas gudang');

-- Units
INSERT INTO units (name, abbreviation) VALUES
('Pieces', 'PCS'),
('Box', 'BOX'),
('Kilogram', 'KG'),
('Gram', 'GR'),
('Liter', 'L'),
('Meter', 'M');

-- Categories
INSERT INTO categories (name, description) VALUES
('Makanan', 'Produk makanan'),
('Minuman', 'Produk minuman'),
('Sembako', 'Kebutuhan pokok'),
('Elektronik', 'Produk elektronik');

-- Customer umum
INSERT INTO customers
(code, name, customer_type)
VALUES
('CUST-001', 'Pelanggan Umum', 'GENERAL');

-- Settings
INSERT INTO settings
(setting_key, setting_value, description)
VALUES
('store_name', 'Toko Saya', 'Nama toko'),
('store_address', 'Jakarta, Indonesia', 'Alamat toko'),
('store_phone', '02100000000', 'Nomor telepon'),
('tax_enabled', '1', 'Aktifkan pajak'),
('tax_rate', '11', 'Persentase PPN'),
('currency', 'IDR', 'Mata uang'),
('invoice_prefix', 'INV', 'Prefix nomor invoice');