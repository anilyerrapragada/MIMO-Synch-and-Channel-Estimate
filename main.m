clc
clear
close all
dbstop if error

rng('default')

tic
snr_diag = 30; % dB

scenarios = {'4G5G', 'MIMOTest', 'Fading', 'IndoorA', 960e3*0.9, 15e3, 0};


num_cases = size(scenarios, 1);


for cc = 1: num_cases
    sys_scenario = scenarios{cc, 1};
    MIMO_method = scenarios{cc, 2};
    wireless_channel = scenarios{cc, 3};
    channel_profile = scenarios{cc, 4};
    channel_band = scenarios{cc, 5};
    bin_spacing = scenarios{cc, 6};
    diagnostic = scenarios{cc, 7};
    
    if strcmpi(MIMO_method, 'None')
        num_ant = 1;
    elseif strcmpi(MIMO_method, 'MIMOTest')
        num_ant = 2;
    else
        num_ant = 2; % change this for various MIMO sizes
    end
    
    system = SystemModel(sys_scenario, MIMO_method, num_ant, wireless_channel, channel_profile, ...
        channel_band, bin_spacing, diagnostic, snr_diag);
    
    NFFT = system.NFFT;
    bin_spacing = system.bin_spacing;
    
    if strcmp(system.CP_type, 'Normal')==1
        CP = round(NFFT/4);  %cyclic prefix (IN Samples !!)
    elseif strcmp(system.CP_type,'Extended')==1
        CP = round(NFFT/4 + NFFT/8);  %cyclic prefix (IN Samples !!)
    end
    
    num_databins = 0.75*NFFT;
    num_synchbins = NFFT - 2;
    %     num_databins = 10;
    mod_type = system.mod_type;
    num_ant = system.num_ant;
    bits_per_bin = system.bits_per_bin;
    OFDM_par = OFDM(NFFT, bin_spacing, CP, num_databins, mod_type, num_ant);
    
    
    if diagnostic == 0
        num_iter = length(system.ebno_dB);
    else
        num_iter = 1;
    end
    
    if strcmpi(MIMO_method, 'MIMOTest')
        if num_ant == 2
        synch_data_pattern = [1, 0, 2, 0; 
                              0, 1, 0, 2];
        elseif num_ant == 4
            synch_data_pattern = [1, 0, 0, 0, 2, 0, 0, 0;
                                  0, 1, 0, 0, 0, 2, 0, 0; 
                                  0, 0, 1, 0, 0, 0, 2, 0;
                                  0, 0, 0, 1, 0, 0, 0, 2];
        end
        symb_pattern = repmat(synch_data_pattern, 1, 3); % 0 - zeros, 1 - synch, 2 - data
        num_symbols = size(symb_pattern, 2); % per subframe? Yes. Per antenna? Yes.
        
        num_data_symb = length(find(symb_pattern(1, :)==2)); % per antenna
        
    else
        %         symb_pattern here should be automated based on number of subframes and
        %         number of symbols per subframe. num_symbols can then simply be
        %         the length of symb_pattern.
        error('Currently not supported');
    end
    
    binary_info = randi([0, 1], num_ant, num_databins*bits_per_bin*num_data_symb);
    
    
    Caz = SynchSignal(CP, num_synchbins, num_ant, NFFT);
    Caz.zadoff_chu_gen([23, 41])
    
    OFDM_par.synch_bin_ind = Caz.synch_bin_ind;
    multiant_sys = MultiAntennaSystem(OFDM_par, system, Caz, num_symbols);
    
    multiant_sys.multiant_binarymap(symb_pattern, binary_info)
    
    multiant_sys.multiant_symbgen(num_symbols);
    
%     for ant = 1: num_ant
%         figure()
%         xax = 1: length(multiant_sys.tx_symbs(ant, :));
%         plot(xax, real(multiant_sys.tx_symbs(ant, :)), xax, imag(multiant_sys.tx_symbs(ant, :)));
%         xlabel('Frequency')
%         ylabel('Amplitude')
%         title(['Antenna ', num2str(ant), ' Amplitude of Tx Symbols'])
%     end
%     
%     for ant = 1: num_ant
%         figure()
%         xax = 1: length(multiant_sys.tx_waveform(ant, :));
%         plot(xax, real(multiant_sys.tx_waveform(ant, :)), xax, imag(multiant_sys.tx_waveform(ant, :)));
%         xlabel('Time')
%         ylabel('Amplitude')
%         title(['Antenna ', num2str(ant), ' Amplitude of Tx Waveform'])
%     end
    
    multiant_sys.channel_gen
    multiant_sys.rxsignal_gen();
    
    rx_sys = RxBasebandSystem(multiant_sys, Caz, system, OFDM_par);
    rx_sys.synchronize(synch_data_pattern, symb_pattern)
    
    dbg = 1;
end

