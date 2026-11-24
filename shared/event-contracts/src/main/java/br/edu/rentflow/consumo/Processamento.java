package br.edu.rentflow.consumo;

import br.edu.rentflow.contrato.Evento;
import org.springframework.transaction.annotation.Transactional;

public class Processamento {
    private final EfeitosRepository repositorio;
    public Processamento(EfeitosRepository repositorio) { this.repositorio = repositorio; }

    @Transactional
    public boolean aplicar(Evento evento, String original, String worker) {
        if (!repositorio.registrar(evento, original)) return false;
        repositorio.criarEfeito(evento, original, worker);
        return true;
    }
}
