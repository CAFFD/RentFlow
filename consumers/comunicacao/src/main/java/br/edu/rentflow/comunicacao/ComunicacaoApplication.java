package br.edu.rentflow.comunicacao;

import br.edu.rentflow.consumo.*;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Import;

@SpringBootApplication
@Import({EntregaListener.class, Processamento.class, ConsultaApi.class})
public class ComunicacaoApplication {
    public static void main(String[] args) { SpringApplication.run(ComunicacaoApplication.class, args); }
}
