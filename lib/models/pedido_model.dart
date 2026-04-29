class Pedido {
  final int id;
  final String nombreCliente;
  final String direccion;
  final double total;

  Pedido({required this.id, required this.nombreCliente, required this.direccion, required this.total});

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      id: json['id'],
      nombreCliente: json['cliente'],
      direccion: json['direccion'],
      total: json['total'],
    );
  }
}