package br.edu.rentflow.manutencao;

import br.edu.rentflow.consumo.*;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Import;

@SpringBootApplication
@Import({EntregaListener.class, Processamento.class, ConsultaApi.class})
public class ManutencaoApplication {
    public static void main(String[] args) { SpringApplication.run(ManutencaoApplication.class, args); }
}
