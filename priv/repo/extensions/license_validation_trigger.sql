-- License validation trigger for PersonRide driver seat enforcement
-- This trigger ensures that only people with the required license can take the driver seat

CREATE OR REPLACE FUNCTION validate_driver_license_trigger()
RETURNS TRIGGER AS $$
DECLARE
  required_license TEXT;
  person_licenses TEXT[];
BEGIN
  -- Only validate driver seats
  IF NEW.seat != 'driver' THEN
    RETURN NEW;
  END IF;

  -- Get required license and person licenses
  SELECT r.required_license, p.licences
  INTO required_license, person_licenses
  FROM rides r, people p
  WHERE r.id = NEW.ride_id AND p.id = NEW.person_id;

  -- Handle case where person or ride not found
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid person_id or ride_id';
  END IF;

  -- No license required - allow
  IF required_license IS NULL THEN
    RETURN NEW;
  END IF;

  -- Check if person has required license
  IF person_licenses IS NULL OR NOT (required_license = ANY(person_licenses)) THEN
    RAISE EXCEPTION 'Driver seat requires % license, person has: %',
                    required_license,
                    COALESCE(array_to_string(person_licenses, ', '), 'no licenses');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
