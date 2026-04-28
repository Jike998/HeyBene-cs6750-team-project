enum ControlLayout {
  dual('Dual', false),
  arrow('Arrow', false),
  oneHandedPortrait('One Hand', true);

  const ControlLayout(this.label, this.isPortrait);

  final String label;
  final bool isPortrait;
}
