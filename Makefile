.PHONY: update clean

# Regenerate idx-template.json from Flutter's sample registry
update:
	@mkdir -p scripts/assets
	flutter create --list-samples=scripts/assets/samples.json
	dart run scripts/update.dart

clean:
	rm -f scripts/assets/samples.json
