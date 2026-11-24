package br.edu.rentflow.consumo;

public class ColisaoDeEvento extends IllegalArgumentException {
    public ColisaoDeEvento() { super("Mesmo eventId com outro envelope"); }
}
