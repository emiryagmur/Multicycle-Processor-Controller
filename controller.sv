module mainfsm (
    input  logic       clk,
    input  logic       reset,
    input  logic [6:0] op,
    output logic [1:0] ALUSrcA, ALUSrcB,
    output logic [1:0] ALUOp,
    output logic [1:0] ResultSrc,
    output logic       AdrSrc,
    output logic       IRWrite,
    output logic       PCUpdate,
    output logic       Branch,
    output logic       RegWrite,
    output logic       MemWrite
);

    typedef enum logic [3:0] {
        FETCH, DECODE, MEMADR, MEMREAD, MEMWB,
        MEMWRITE, EXECUTER, ALUWB, EXECUTEI, JAL, BEQ
    } statetype;

    statetype state, nextstate;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) state <= FETCH;
        else       state <= nextstate;
    end

    always_comb begin
        case (state)
            FETCH:    nextstate = DECODE;
            DECODE:   case (op)
                        7'b0000011, 7'b0100011: nextstate = MEMADR;
                        7'b0110011:             nextstate = EXECUTER;
                        7'b0010011:             nextstate = EXECUTEI;
                        7'b1101111:             nextstate = JAL;
                        7'b1100011:             nextstate = BEQ;
                        default:                nextstate = FETCH;
                      endcase
            MEMADR:   case (op)
                        7'b0000011: nextstate = MEMREAD;
                        7'b0100011: nextstate = MEMWRITE;
                        default:    nextstate = FETCH;
                      endcase
            MEMREAD:  nextstate = MEMWB;
            MEMWB:    nextstate = FETCH;
            MEMWRITE: nextstate = FETCH;
            EXECUTER: nextstate = ALUWB;
            EXECUTEI: nextstate = ALUWB;
            ALUWB:    nextstate = FETCH;
            JAL:      nextstate = ALUWB;
            BEQ:      nextstate = FETCH;
            default:  nextstate = FETCH;
        endcase
    end

    always_comb begin
        AdrSrc    = 1'b0;
        IRWrite   = 1'b0;
        ALUSrcA   = 2'b00;
        ALUSrcB   = 2'b00;
        ALUOp     = 2'b00;
        ResultSrc = 2'b00;
        PCUpdate  = 1'b0;
        Branch    = 1'b0;
        RegWrite  = 1'b0;
        MemWrite  = 1'b0;

        case (state)
            FETCH: begin
                AdrSrc    = 1'b0;
                IRWrite   = 1'b1;
                ALUSrcA   = 2'b00;
                ALUSrcB   = 2'b10;
                ALUOp     = 2'b00;
                ResultSrc = 2'b10;
                PCUpdate  = 1'b1;
            end
            DECODE: begin
                ALUSrcA   = 2'b01;
                ALUSrcB   = 2'b01;
                ALUOp     = 2'b00;
            end
            MEMADR: begin
                ALUSrcA   = 2'b10;
                ALUSrcB   = 2'b01;
                ALUOp     = 2'b00;
            end
            MEMREAD: begin
                ResultSrc = 2'b00;
                AdrSrc    = 1'b1;
            end
            MEMWB: begin
                ResultSrc = 2'b01;
                RegWrite  = 1'b1;
            end
            MEMWRITE: begin
                ResultSrc = 2'b00;
                AdrSrc    = 1'b1;
                MemWrite  = 1'b1;
            end
            EXECUTER: begin
                ALUSrcA   = 2'b10;
                ALUSrcB   = 2'b00;
                ALUOp     = 2'b10;
            end
            EXECUTEI: begin
                ALUSrcA   = 2'b10;
                ALUSrcB   = 2'b01;
                ALUOp     = 2'b10;
            end
            ALUWB: begin
                ResultSrc = 2'b00;
                RegWrite  = 1'b1;
            end
            JAL: begin
                ALUSrcA   = 2'b01;
                ALUSrcB   = 2'b10;
                ALUOp     = 2'b00;
                ResultSrc = 2'b00;
                PCUpdate  = 1'b1;
            end
            BEQ: begin
                ALUSrcA   = 2'b10;
                ALUSrcB   = 2'b00;
                ALUOp     = 2'b01;
                ResultSrc = 2'b00;
                Branch    = 1'b1;
            end
        endcase
    end
endmodule

module aludec (
    input  logic       opb5,
    input  logic [2:0] funct3,
    input  logic       funct7b5,
    input  logic [1:0] ALUOp,
    output logic [2:0] ALUControl
);
    logic RtypeSub;
    assign RtypeSub = funct7b5 & opb5;

    always_comb begin
        case (ALUOp)
            2'b00: ALUControl = 3'b000;
            2'b01: ALUControl = 3'b001;
            2'b10: case (funct3) // Bu k?sm? default yerine aç?kça 2'b10 yapt?k
                         3'b000: if (RtypeSub) ALUControl = 3'b001;
                                 else          ALUControl = 3'b000;
                         3'b010:               ALUControl = 3'b101;
                         3'b110:               ALUControl = 3'b011;
                         3'b111:               ALUControl = 3'b010;
                         default:              ALUControl = 3'b000;
                     endcase
            default: ALUControl = 3'b000; // Güvenlik için ana default
        endcase
    end
endmodule

module instrdec (
    input  logic [6:0] op,
    output logic [1:0] ImmSrc
);
    always_comb begin
        case (op)
            7'b0110011: ImmSrc = 2'b00;
            7'b0010011: ImmSrc = 2'b00;
            7'b0000011: ImmSrc = 2'b00;
            7'b0100011: ImmSrc = 2'b01;
            7'b1100011: ImmSrc = 2'b10;
            7'b1101111: ImmSrc = 2'b11;
            default:    ImmSrc = 2'b00;
        endcase
    end
endmodule

module controller (
    input  logic       clk,
    input  logic       reset,
    input  logic [6:0] op,
    input  logic [2:0] funct3,
    input  logic       funct7b5,
    input  logic       zero,
    output logic [1:0] immsrc,
    output logic [1:0] alusrca, alusrcb,
    output logic [1:0] resultsrc,
    output logic       adrsrc,
    output logic [2:0] alucontrol,
    output logic       irwrite, pcwrite,
    output logic       regwrite, memwrite
);

    logic [1:0] aluop;
    logic branch, pcupdate;

    mainfsm fsm (
        .clk(clk), 
        .reset(reset), 
        .op(op),
        .ALUSrcA(alusrca), 
        .ALUSrcB(alusrcb),
        .ALUOp(aluop), 
        .ResultSrc(resultsrc),
        .AdrSrc(adrsrc), 
        .IRWrite(irwrite),
        .PCUpdate(pcupdate), 
        .Branch(branch),
        .RegWrite(regwrite), 
        .MemWrite(memwrite)
    );

    aludec ad (
        .opb5(op[5]), 
        .funct3(funct3), 
        .funct7b5(funct7b5),
        .ALUOp(aluop), 
        .ALUControl(alucontrol)
    );

    instrdec id (
        .op(op), 
        .ImmSrc(immsrc)
    );

    assign pcwrite = pcupdate | (branch & zero);

endmodule