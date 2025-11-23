-- Seed data for testing menu analytics for week starting 2025-11-03 (Monday)
-- Uses provided admin parent user id: d25cf9ff-183b-4670-a893-99c7cdb80ac1
-- Creates a student if none exists for that parent, inserts menu_items (if missing),
-- and adds orders across the week using JSONB items with menuItemId/menuItemName/quantity.

DO $$
DECLARE
  v_parent UUID := 'd25cf9ff-183b-4670-a893-99c7cdb80ac1';
  v_student UUID;
  v_pancit UUID;
  v_adobo UUID;
  v_sinigang UUID;
  v_chicken UUID;
  v_lumpia UUID;
  v_banana UUID;
  v_turon UUID;
  v_buko UUID;
  v_calamansi UUID;
  v_puto UUID;
BEGIN
  -- Ensure at least one student exists for this parent
  SELECT id INTO v_student FROM students WHERE parent_user_id = v_parent LIMIT 1;
  IF v_student IS NULL THEN
    INSERT INTO students(parent_user_id, first_name, last_name, grade_level, section)
    VALUES (v_parent, 'Test', 'Student', 'Grade 3', 'A')
    RETURNING id INTO v_student;
  END IF;

  -- Helper: upsert-by-name to capture menu item id
  -- Pancit Canton
  SELECT id INTO v_pancit FROM menu_items WHERE name = 'Pancit Canton' LIMIT 1;
  IF v_pancit IS NULL THEN
    INSERT INTO menu_items(name, description, price, category, is_available, allergens, dietary_labels, prep_time_minutes)
    VALUES ('Pancit Canton','Filipino stir-fried noodles with vegetables and chicken',45.00,'Lunch',true, ARRAY['Wheat'], ARRAY[]::text[], 15)
    RETURNING id INTO v_pancit;
  END IF;

  -- Adobong Manok
  SELECT id INTO v_adobo FROM menu_items WHERE name = 'Adobong Manok' LIMIT 1;
  IF v_adobo IS NULL THEN
    INSERT INTO menu_items(name, description, price, category, is_available, allergens, dietary_labels, prep_time_minutes)
    VALUES ('Adobong Manok','Classic Filipino chicken adobo with rice',55.00,'Lunch',true, ARRAY[]::text[], ARRAY['Gluten-Free'], 25)
    RETURNING id INTO v_adobo;
  END IF;

  -- Sinigang na Baboy
  SELECT id INTO v_sinigang FROM menu_items WHERE name = 'Sinigang na Baboy' LIMIT 1;
  IF v_sinigang IS NULL THEN
    INSERT INTO menu_items(name, description, price, category, is_available, allergens, dietary_labels, prep_time_minutes)
    VALUES ('Sinigang na Baboy','Pork in sour tamarind broth with vegetables',60.00,'Lunch',true, ARRAY[]::text[], ARRAY['Gluten-Free','Dairy-Free'], 30)
    RETURNING id INTO v_sinigang;
  END IF;

  -- Fried Chicken
  SELECT id INTO v_chicken FROM menu_items WHERE name = 'Fried Chicken' LIMIT 1;
  IF v_chicken IS NULL THEN
    INSERT INTO menu_items(name, description, price, category, is_available, allergens, dietary_labels, prep_time_minutes)
    VALUES ('Fried Chicken','Crispy fried chicken with rice',50.00,'Lunch',true, ARRAY['Wheat'], ARRAY[]::text[], 20)
    RETURNING id INTO v_chicken;
  END IF;

  -- Lumpia Shanghai
  SELECT id INTO v_lumpia FROM menu_items WHERE name = 'Lumpia Shanghai' LIMIT 1;
  IF v_lumpia IS NULL THEN
    INSERT INTO menu_items(name, description, price, category, is_available, allergens, dietary_labels, prep_time_minutes)
    VALUES ('Lumpia Shanghai','Crispy Filipino spring rolls',35.00,'Lunch',true, ARRAY['Wheat'], ARRAY[]::text[], 10)
    RETURNING id INTO v_lumpia;
  END IF;

  -- Banana Cue
  SELECT id INTO v_banana FROM menu_items WHERE name = 'Banana Cue' LIMIT 1;
  IF v_banana IS NULL THEN
    INSERT INTO menu_items(name, description, price, category, is_available, allergens, dietary_labels, prep_time_minutes)
    VALUES ('Banana Cue','Deep-fried caramelized banana on a stick',15.00,'Snack',true, ARRAY['Soy'], ARRAY['Vegetarian','Vegan','Gluten-Free'], 5)
    RETURNING id INTO v_banana;
  END IF;

  -- Turon
  SELECT id INTO v_turon FROM menu_items WHERE name = 'Turon' LIMIT 1;
  IF v_turon IS NULL THEN
    INSERT INTO menu_items(name, description, price, category, is_available, allergens, dietary_labels, prep_time_minutes)
    VALUES ('Turon','Fried banana spring roll with jackfruit',20.00,'Snack',true, ARRAY['Wheat'], ARRAY['Vegetarian'], 8)
    RETURNING id INTO v_turon;
  END IF;

  -- Fresh Buko Juice
  SELECT id INTO v_buko FROM menu_items WHERE name = 'Fresh Buko Juice' LIMIT 1;
  IF v_buko IS NULL THEN
    INSERT INTO menu_items(name, description, price, category, is_available, allergens, dietary_labels, prep_time_minutes)
    VALUES ('Fresh Buko Juice','Refreshing young coconut juice',25.00,'Drinks',true, ARRAY[]::text[], ARRAY['Vegetarian','Vegan','Gluten-Free','Organic'], 2)
    RETURNING id INTO v_buko;
  END IF;

  -- Calamansi Juice
  SELECT id INTO v_calamansi FROM menu_items WHERE name = 'Calamansi Juice' LIMIT 1;
  IF v_calamansi IS NULL THEN
    INSERT INTO menu_items(name, description, price, category, is_available, allergens, dietary_labels, prep_time_minutes)
    VALUES ('Calamansi Juice','Filipino lime juice',20.00,'Drinks',true, ARRAY[]::text[], ARRAY['Vegetarian','Vegan','Gluten-Free'], 2)
    RETURNING id INTO v_calamansi;
  END IF;

  -- Puto
  SELECT id INTO v_puto FROM menu_items WHERE name = 'Puto' LIMIT 1;
  IF v_puto IS NULL THEN
    INSERT INTO menu_items(name, description, price, category, is_available, allergens, dietary_labels, prep_time_minutes)
    VALUES ('Puto','Steamed rice cake',10.00,'Snack',true, ARRAY[]::text[], ARRAY['Vegetarian','Gluten-Free'], 12)
    RETURNING id INTO v_puto;
  END IF;

  -- Insert orders (Mon-Fri)
  -- Monday 2025-11-03
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0001', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_pancit::text, 'menuItemName','Lunch - Pancit Canton','quantity',2)), 90.00, 'completed','one-time','2025-11-03');
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0002', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_buko::text, 'menuItemName','Drinks - Fresh Buko Juice','quantity',3)), 75.00, 'completed','one-time','2025-11-03');
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0003', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_turon::text, 'menuItemName','Snack - Turon','quantity',4)), 80.00, 'completed','one-time','2025-11-03');

  -- Tuesday 2025-11-04
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0004', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_adobo::text, 'menuItemName','Lunch - Adobong Manok','quantity',1)), 55.00, 'completed','one-time','2025-11-04');
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0005', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_calamansi::text, 'menuItemName','Drinks - Calamansi Juice','quantity',2)), 40.00, 'completed','one-time','2025-11-04');
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0006', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_banana::text, 'menuItemName','Snack - Banana Cue','quantity',5)), 75.00, 'completed','one-time','2025-11-04');

  -- Wednesday 2025-11-05
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0007', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_chicken::text, 'menuItemName','Lunch - Fried Chicken','quantity',3)), 150.00, 'completed','one-time','2025-11-05');
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0008', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_puto::text, 'menuItemName','Snack - Puto','quantity',6)), 60.00, 'completed','one-time','2025-11-05');
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0009', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_buko::text, 'menuItemName','Drinks - Fresh Buko Juice','quantity',2)), 50.00, 'completed','one-time','2025-11-05');

  -- Thursday 2025-11-06
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0010', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_lumpia::text, 'menuItemName','Lunch - Lumpia Shanghai','quantity',4)), 140.00, 'completed','one-time','2025-11-06');
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0011', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_calamansi::text, 'menuItemName','Drinks - Calamansi Juice','quantity',3)), 60.00, 'completed','one-time','2025-11-06');

  -- Friday 2025-11-07
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0012', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_sinigang::text, 'menuItemName','Lunch - Sinigang na Baboy','quantity',2)), 120.00, 'completed','one-time','2025-11-07');
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0013', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_banana::text, 'menuItemName','Snack - Banana Cue','quantity',3)), 45.00, 'completed','one-time','2025-11-07');
  INSERT INTO orders(order_number, parent_id, student_id, items, total_amount, status, order_type, delivery_date)
  VALUES ('ORD-0014', v_parent, v_student, jsonb_build_array(jsonb_build_object('menuItemId', v_buko::text, 'menuItemName','Drinks - Fresh Buko Juice','quantity',4)), 100.00, 'completed','one-time','2025-11-07');

END $$;
