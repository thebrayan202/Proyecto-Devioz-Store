CREATE TABLE IF NOT EXISTS product_nutrition (
  product_id INT UNSIGNED NOT NULL PRIMARY KEY,
  applicability ENUM('food','non_food','review') NOT NULL DEFAULT 'review',
  energy_kcal_100g DECIMAL(10,2) NULL,
  serving_size DECIMAL(10,2) NULL,
  serving_unit ENUM('g','ml','unit') NULL,
  energy_kcal_serving DECIMAL(10,2) NULL,
  protein_g DECIMAL(10,2) NULL,
  carbohydrate_g DECIMAL(10,2) NULL,
  fat_g DECIMAL(10,2) NULL,
  source_type ENUM('label','open_food_facts','ins','usda','manual') NULL,
  source_ref VARCHAR(255) NULL,
  confidence ENUM('verified','reference') NULL,
  verified_at DATETIME NULL,
  verified_by INT UNSIGNED NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_product_nutrition_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
