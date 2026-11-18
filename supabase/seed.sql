-- Sample reference data for development.
--
-- Everything here is a placeholder standing in for the datasets the proposal
-- names: the DOE EVCS Locator and Open Charge Map (stations), manufacturers'
-- specifications (vehicles), brand service networks (providers), and
-- published rates. Replace it with collected data before evaluation.
--
-- Run once in the Supabase SQL editor after the migrations.

insert into public.vehicles (brand, model, type, connectors, battery_kwh, kwh_per_km, source) values
  ('BYD', 'Atto 3', 'bev', '{ccs2,type2}', 60.5, 0.156, 'Sample data'),
  ('BYD', 'Dolphin', 'bev', '{ccs2,type2}', 44.9, 0.140, 'Sample data'),
  ('BYD', 'Sealion 6 DM-i', 'phev', '{type2}', 18.3, 0.190, 'Sample data'),
  ('Tesla', 'Model 3', 'bev', '{ccs2,type2}', 60, 0.140, 'Sample data'),
  ('Nissan', 'Leaf', 'bev', '{chademo,type2}', 40, 0.160, 'Sample data'),
  ('VinFast', 'VF 5', 'bev', '{ccs2,type2}', 37.2, 0.135, 'Sample data'),
  ('Kia', 'EV6', 'bev', '{ccs2,type2}', 77.4, 0.170, 'Sample data')
on conflict (brand, model) do nothing;

insert into public.stations (name, operator, address, city, lat, lng, connectors, fee, hours, parking, source) values
  ('Makati CBD Charging Hub', 'Metro Charge', 'Ayala Avenue, Makati', 'Makati', 14.5547, 121.0244,
    '[{"type":"ccs2","power_kw":60},{"type":"type2","power_kw":22}]', '₱28 per kWh', '24 hours', 'Paid mall parking; four EV-only bays', 'Sample data'),
  ('BGC High Street Chargers', 'Volt Avenue', '9th Avenue, Bonifacio Global City', 'Taguig', 14.5507, 121.0509,
    '[{"type":"ccs2","power_kw":120},{"type":"type2","power_kw":7}]', '₱32 per kWh', '6 AM to 12 MN', 'Basement parking; two EV-only bays', 'Sample data'),
  ('Bay Area Fast Charge', 'Metro Charge', 'Seaside Boulevard, Pasay', 'Pasay', 14.5352, 120.9822,
    '[{"type":"ccs2","power_kw":60},{"type":"chademo","power_kw":50}]', '₱30 per kWh', '10 AM to 10 PM', 'Open parking; fees apply after three hours', 'Sample data'),
  ('Quezon City Triangle Chargers', 'North Grid EV', 'Triangle Park, Quezon City', 'Quezon City', 14.6445, 121.0370,
    '[{"type":"type2","power_kw":22},{"type":"gbt","power_kw":60}]', '₱25 per kWh', '8 AM to 10 PM', 'Free parking for the first two hours', 'Sample data'),
  ('Ortigas Center Charging Point', 'Volt Avenue', 'Emerald Avenue, Pasig', 'Pasig', 14.5873, 121.0615,
    '[{"type":"ccs2","power_kw":50},{"type":"type2","power_kw":11}]', '₱29 per kWh', '24 hours', 'Building parking; rates not published', 'Sample data'),
  ('Alabang Town Charging Point', 'South Grid EV', 'Commerce Avenue, Alabang', 'Muntinlupa', 14.4237, 121.0297,
    '[{"type":"ccs2","power_kw":60},{"type":"type2","power_kw":22}]', '₱27 per kWh', '10 AM to 9 PM', 'Mall parking; three EV-only bays', 'Sample data'),
  ('Sta. Rosa Greenfield Chargers', 'South Grid EV', 'Greenfield Parkway, Sta. Rosa', 'Sta. Rosa', 14.2443, 121.0570,
    '[{"type":"ccs2","power_kw":120}]', '₱33 per kWh', '24 hours', 'Open parking, no fee', 'Sample data'),
  ('Calamba Expressway Stop Charger', 'Expressway Charge', 'SLEX southbound service area, Calamba', 'Calamba', 14.2117, 121.1340,
    '[{"type":"ccs2","power_kw":60},{"type":"chademo","power_kw":50}]', '₱35 per kWh', '24 hours', 'Service area parking, no fee', 'Sample data'),
  ('Tagaytay Ridge Charging Stop', 'Ridge Power', 'Aguinaldo Highway, Tagaytay', 'Tagaytay', 14.1153, 120.9621,
    '[{"type":"ccs2","power_kw":50},{"type":"type2","power_kw":22}]', '₱30 per kWh', '7 AM to 9 PM', 'Restaurant parking for customers', 'Sample data'),
  ('Lipa City Charging Point', 'South Grid EV', 'JP Laurel Highway, Lipa', 'Lipa', 13.9411, 121.1631,
    '[{"type":"ccs2","power_kw":60}]', '₱31 per kWh', '8 AM to 8 PM', 'Open parking, no fee', 'Sample data'),
  ('Batangas City Charging Hub', 'South Grid EV', 'P. Burgos Street, Batangas City', 'Batangas City', 13.7565, 121.0583,
    '[{"type":"ccs2","power_kw":60},{"type":"type2","power_kw":22}]', '₱31 per kWh', '8 AM to 9 PM', 'Paid parking', 'Sample data'),
  ('Antipolo Hilltop Charger', 'North Grid EV', 'Sumulong Highway, Antipolo', 'Antipolo', 14.5860, 121.1761,
    '[{"type":"type2","power_kw":7}]', 'Free for customers', '9 AM to 9 PM', 'Customer parking only', 'Sample data'),
  ('Imus Fast Charge', 'Expressway Charge', 'Aguinaldo Highway, Imus', 'Imus', 14.4297, 120.9367,
    '[{"type":"ccs2","power_kw":60},{"type":"gbt","power_kw":60}]', '₱30 per kWh', '24 hours', 'Open parking, no fee', 'Sample data');

-- Directory entries with no owner account, already verified.
insert into public.providers (name, category, description, brands, services, address, city, lat, lng, contact, status) values
  ('GreenTorque Tires and Alignment', 'tires', 'EV-rated tires, alignment and balancing.',
    '{All brands}', '{EV-rated tires,Wheel alignment,Balancing}', 'Quezon Avenue, Quezon City', 'Quezon City', 14.6360, 121.0200, '(02) 8555 0178', 'approved'),
  ('South Charge Parts and Accessories', 'parts', 'Portable chargers, adapters, cabin filters and accessories.',
    '{BYD,VinFast,Nissan}', '{Portable chargers,Adapters,Cabin filters,Floor mats}', 'Balibago Road, Sta. Rosa', 'Sta. Rosa', 14.2900, 121.1050, '(049) 555 0120', 'approved'),
  ('Alabang Authorized EV Service', 'dealership', 'Dealership service department for authorized maintenance and warranty work.',
    '{BYD}', '{Authorized maintenance,Warranty repairs,Software checks}', 'Alabang–Zapote Road, Muntinlupa', 'Muntinlupa', 14.4300, 121.0200, '(02) 8555 0190', 'approved');

insert into public.reference_data (name, value, source) values
  ('Charging station list', '13 sample stations', 'Sample data (to be replaced by DOE EVCS Locator and Open Charge Map)'),
  ('Household electricity rate', '₱15.55 per kWh', 'Sample default (Meralco published rate; users can enter their own)'),
  ('Public charging rate', '₱35.00 per kWh', 'Sample default (operators'' published rates)'),
  ('Gasoline pump price', '₱60.00 per liter', 'Sample default (DOE retail pump prices; users can enter their own)'),
  ('Vehicle specifications', '7 sample models', 'Sample data (manufacturers'' published specifications)'),
  ('Service provider seed list', '3 sample listings', 'Sample data (brand service networks, NCR and CALABARZON)')
on conflict (name) do nothing;

-- To make an account the platform administrator, run this with the user's id
-- from Authentication > Users:
--   update public.profiles set role = 'admin' where id = '<user id>';
